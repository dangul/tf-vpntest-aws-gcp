terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

locals {
  aws_bgp_ip = cidrhost(var.tunnel_inside_cidr, 1) # 169.254.10.1
  gcp_bgp_ip = cidrhost(var.tunnel_inside_cidr, 2) # 169.254.10.2
}

############################
# GCP: nätverk + HA VPN
############################
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = var.gcp_subnet_cidr
  network       = google_compute_network.vpc.id
}

resource "google_compute_ha_vpn_gateway" "gw" {
  name    = "${var.name_prefix}-ha-gw"
  network = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  network = google_compute_network.vpc.id
  bgp {
    asn = var.gcp_bgp_asn
  }
}

############################
# AWS: VPC + VGW + VPN
############################
resource "aws_vpc" "vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.aws_vpc_cidr
  tags       = { Name = "${var.name_prefix}-subnet" }
}

resource "aws_vpn_gateway" "vgw" {
  vpc_id          = aws_vpc.vpc.id
  amazon_side_asn = var.aws_bgp_asn
  tags            = { Name = "${var.name_prefix}-vgw" }
}

resource "aws_customer_gateway" "cgw" {
  bgp_asn    = var.gcp_bgp_asn
  ip_address = google_compute_ha_vpn_gateway.gw.vpn_interfaces[0].ip_address
  type       = "ipsec.1"
  tags       = { Name = "${var.name_prefix}-cgw" }
}

resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"
  static_routes_only  = false

  # Endast tunnel 1 används (single tunnel)
  tunnel1_inside_cidr = var.tunnel_inside_cidr
  tags                = { Name = "${var.name_prefix}-vpn" }
}

# Route propagation så VPC lär sig GCP-nätet via BGP
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = "${var.name_prefix}-rt" }
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_vpn_gateway_route_propagation" "prop" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = aws_route_table.rt.id
}

############################
# GCP: koppla till AWS tunnel 1
############################
resource "google_compute_external_vpn_gateway" "peer" {
  name            = "${var.name_prefix}-peer-gw"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  interface {
    id         = 0
    ip_address = aws_vpn_connection.vpn.tunnel1_address
  }
}

resource "google_compute_vpn_tunnel" "tunnel" {
  name                            = "${var.name_prefix}-tunnel"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gw.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.peer.id
  peer_external_gateway_interface = 0
  shared_secret                   = aws_vpn_connection.vpn.tunnel1_preshared_key
  router                          = google_compute_router.router.id
  ike_version                     = 2
}

resource "google_compute_router_interface" "if" {
  name       = "${var.name_prefix}-if"
  router     = google_compute_router.router.name
  ip_range   = "${local.gcp_bgp_ip}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel.name
}

resource "google_compute_router_peer" "peer" {
  name                      = "${var.name_prefix}-bgp"
  router                    = google_compute_router.router.name
  interface                 = google_compute_router_interface.if.name
  peer_ip_address           = local.aws_bgp_ip
  peer_asn                  = var.aws_bgp_asn
  advertised_route_priority = 100
}

############################
# Brandväggar (för ping-test)
############################
resource "google_compute_firewall" "allow_aws" {
  name    = "${var.name_prefix}-allow-aws"
  network = google_compute_network.vpc.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.aws_vpc_cidr]
}

resource "aws_security_group" "allow_gcp" {
  name   = "${var.name_prefix}-allow-gcp"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.gcp_subnet_cidr]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.gcp_subnet_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
