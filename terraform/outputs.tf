output "transit_gateway_id" {
  description = "ID of the regional Transit Gateway hub."
  value       = aws_ec2_transit_gateway.hub.id
}

output "vpc_ids" {
  description = "Environment-to-VPC ID map."
  value       = { for key, vpc in aws_vpc.environment : key => vpc.id }
}

output "vpn_connection_id" {
  description = "Site-to-Site VPN connection ID."
  value       = aws_vpn_connection.hybrid.id
}

output "vpn_tunnel_public_ips" {
  description = "AWS public endpoints to configure on the customer gateway."
  value = [
    aws_vpn_connection.hybrid.tunnel1_address,
    aws_vpn_connection.hybrid.tunnel2_address,
  ]
}

output "vpn_preshared_key_secret_arn" {
  description = "Secrets Manager ARN containing the generated VPN pre-shared keys."
  value       = aws_vpn_connection.hybrid.preshared_key_arn
  sensitive   = true
}

output "customer_gateway_configuration" {
  description = "Vendor-neutral VPN configuration XML. Write it to a protected file and translate it for the customer router."
  value       = aws_vpn_connection.hybrid.customer_gateway_configuration
  sensitive   = true
}

output "resolver_inbound_ips" {
  description = "Configure on-premises conditional forwarding for private_aws_domain to these addresses."
  value       = [for ip in aws_route53_resolver_endpoint.inbound.ip_address : ip.ip]
}

output "resolver_outbound_ips" {
  description = "Source addresses used when AWS forwards on_prem_domain queries to the data center."
  value       = [for ip in aws_route53_resolver_endpoint.outbound.ip_address : ip.ip]
}

output "private_zone_name" {
  description = "Private AWS DNS suffix."
  value       = aws_route53_zone.private.name
}

output "network_firewall_arn" {
  description = "Central Network Firewall ARN when inspection is enabled."
  value       = var.enable_network_firewall ? aws_networkfirewall_firewall.central[0].arn : null
}

output "audit_bucket_name" {
  description = "S3 bucket receiving CloudTrail and AWS Config data."
  value       = aws_s3_bucket.audit.id
}

