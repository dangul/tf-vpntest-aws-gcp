# --- Allmänt ---
variable "name_prefix" {
  type    = string
  default = "labb"
}

# --- AWS ---
variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "aws_bgp_asn" {
  type    = number
  default = 65010
}

# --- GCP ---
variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-north1"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.20.0.0/24"
}

variable "gcp_bgp_asn" {
  type    = number
  default = 65020
}

# --- Tunnel ---
variable "tunnel_inside_cidr" {
  description = "/30 inom 169.254.0.0/16. AWS får .1, GCP får .2"
  type        = string
  default     = "169.254.10.0/30"
}
