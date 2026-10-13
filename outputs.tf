output "gcp_vpn_ip" {
  value = google_compute_ha_vpn_gateway.gw.vpn_interfaces[0].ip_address
}

output "aws_vpn_ip" {
  value = aws_vpn_connection.vpn.tunnel1_address
}

output "bgp_ips" {
  value = "AWS=${local.aws_bgp_ip}  GCP=${local.gcp_bgp_ip}"
}
