resource "aws_security_group" "resolver" {
  name        = "${var.project_name}-resolver"
  description = "Hybrid DNS between Route 53 Resolver and connected networks"
  vpc_id      = aws_vpc.environment["shared"].id

  tags = {
    Name = "${var.project_name}-resolver"
  }
}

resource "aws_vpc_security_group_ingress_rule" "resolver_udp" {
  for_each = toset(local.connected_cidrs)

  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = each.value
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "DNS over UDP from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "resolver_tcp" {
  for_each = toset(local.connected_cidrs)

  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = each.value
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "DNS over TCP from ${each.value}"
}

resource "aws_vpc_security_group_egress_rule" "resolver_udp" {
  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = var.on_prem_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "Forward DNS over UDP to on-premises servers"
}

resource "aws_vpc_security_group_egress_rule" "resolver_tcp" {
  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = var.on_prem_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "Forward DNS over TCP to on-premises servers"
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name                   = "${var.project_name}-inbound"
  direction              = "INBOUND"
  resolver_endpoint_type = "IPV4"
  protocols              = ["Do53"]
  security_group_ids     = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = local.shared_subnet_keys
    content {
      subnet_id = aws_subnet.private[ip_address.value].id
    }
  }

  tags = {
    Name = "${var.project_name}-inbound"
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name                   = "${var.project_name}-outbound"
  direction              = "OUTBOUND"
  resolver_endpoint_type = "IPV4"
  protocols              = ["Do53"]
  security_group_ids     = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = local.shared_subnet_keys
    content {
      subnet_id = aws_subnet.private[ip_address.value].id
    }
  }

  tags = {
    Name = "${var.project_name}-outbound"
  }
}

resource "aws_route53_resolver_rule" "on_premises" {
  domain_name          = var.on_prem_domain
  name                 = "${var.project_name}-to-on-premises"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  dynamic "target_ip" {
    for_each = var.on_prem_dns_ips
    content {
      ip   = target_ip.value
      port = 53
    }
  }

  tags = {
    Name = "${var.project_name}-to-on-premises"
  }
}

resource "aws_route53_resolver_rule_association" "on_premises" {
  for_each = local.vpcs

  name             = "${var.project_name}-${each.key}-on-premises"
  resolver_rule_id = aws_route53_resolver_rule.on_premises.id
  vpc_id           = aws_vpc.environment[each.key].id
}

resource "aws_route53_zone" "private" {
  name = var.private_aws_domain

  vpc {
    vpc_id = aws_vpc.environment["shared"].id
  }

  tags = {
    Name = "${var.project_name}-private-zone"
  }
}

resource "aws_route53_zone_association" "private" {
  for_each = { for key, value in local.vpcs : key => value if key != "shared" }

  zone_id = aws_route53_zone.private.zone_id
  vpc_id  = aws_vpc.environment[each.key].id
}

resource "aws_route53_record" "verification" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "connectivity.${var.private_aws_domain}"
  type    = "TXT"
  ttl     = 60
  records = ["hybrid-dns-ready"]
}

