resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/aws/vpn/${var.project_name}"
  retention_in_days = 30
}

resource "aws_customer_gateway" "on_premises" {
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project_name}-on-premises"
  }
}

resource "aws_vpn_connection" "hybrid" {
  customer_gateway_id = aws_customer_gateway.on_premises.id
  transit_gateway_id  = aws_ec2_transit_gateway.hub.id
  type                = "ipsec.1"

  static_routes_only       = false
  local_ipv4_network_cidr  = var.on_prem_cidr
  remote_ipv4_network_cidr = "10.0.0.0/8"
  preshared_key_storage    = "SecretsManager"

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [19]
  tunnel2_phase1_dh_group_numbers      = [19]
  tunnel1_phase2_dh_group_numbers      = [19]
  tunnel2_phase2_dh_group_numbers      = [19]
  tunnel1_dpd_timeout_action           = "restart"
  tunnel2_dpd_timeout_action           = "restart"
  tunnel1_startup_action               = "start"
  tunnel2_startup_action               = "start"

  tunnel1_log_options {
    cloudwatch_log_options {
      bgp_log_enabled       = true
      bgp_log_group_arn     = aws_cloudwatch_log_group.vpn.arn
      bgp_log_output_format = "json"
      log_enabled           = true
      log_group_arn         = aws_cloudwatch_log_group.vpn.arn
      log_output_format     = "json"
    }
  }

  tunnel2_log_options {
    cloudwatch_log_options {
      bgp_log_enabled       = true
      bgp_log_group_arn     = aws_cloudwatch_log_group.vpn.arn
      bgp_log_output_format = "json"
      log_enabled           = true
      log_group_arn         = aws_cloudwatch_log_group.vpn.arn
      log_output_format     = "json"
    }
  }

  tags = {
    Name = "${var.project_name}-vpn"
  }
}

resource "aws_ec2_tag" "vpn_attachment_name" {
  resource_id = aws_vpn_connection.hybrid.transit_gateway_attachment_id
  key         = "Name"
  value       = "${var.project_name}-vpn-attachment"
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_ingress" {
  transit_gateway_attachment_id  = aws_vpn_connection.hybrid.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ingress.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_post_inspection" {
  count = var.enable_network_firewall ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.hybrid.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_direct" {
  count = var.enable_network_firewall ? 0 : 1

  transit_gateway_attachment_id  = aws_vpn_connection.hybrid.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ingress.id
}

