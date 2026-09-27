resource "aws_vpc" "environment" {
  for_each = local.vpcs

  cidr_block           = each.value.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = each.value.environment
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.environment[each.value.vpc_key].id
  cidr_block              = each.value.cidr
  availability_zone       = data.aws_availability_zones.available.names[each.value.az_index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-${each.value.vpc_key}-${data.aws_availability_zones.available.names[each.value.az_index]}"
    Environment = local.vpcs[each.value.vpc_key].environment
    Tier        = "Private"
  }
}

resource "aws_route_table" "private" {
  for_each = local.vpcs

  vpc_id = aws_vpc.environment[each.key].id

  tags = {
    Name = "${var.project_name}-${each.key}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.vpc_key].id
}

resource "aws_ec2_transit_gateway" "hub" {
  description                     = "Hybrid network hub for ${var.project_name}"
  amazon_side_asn                 = var.transit_gateway_bgp_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "${var.project_name}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each = local.vpcs

  subnet_ids                                      = [for key, subnet in local.private_subnets : aws_subnet.private[key].id if subnet.vpc_key == each.key]
  transit_gateway_id                              = aws_ec2_transit_gateway.hub.id
  vpc_id                                          = aws_vpc.environment[each.key].id
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "${var.project_name}-${each.key}-attachment"
  }
}

resource "aws_route" "aws_networks" {
  for_each = local.vpcs

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.hub.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

resource "aws_route" "on_premises" {
  for_each = local.vpcs

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = var.on_prem_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.hub.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

resource "aws_ec2_transit_gateway_route_table" "ingress" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id

  tags = {
    Name = "${var.project_name}-ingress"
  }
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id

  tags = {
    Name = "${var.project_name}-post-inspection"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_ingress" {
  for_each = aws_ec2_transit_gateway_vpc_attachment.spoke

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ingress.id
}

# With inspection enabled, every connected CIDR first points to the firewall
# attachment. The firewall attachment is associated with the post-inspection
# table, where the real destination attachments are selected.
resource "aws_ec2_transit_gateway_route" "via_firewall" {
  for_each = var.enable_network_firewall ? toset(local.connected_cidrs) : toset([])

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = local.firewall_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ingress.id
}

resource "aws_ec2_transit_gateway_route" "inspection_to_spoke" {
  for_each = var.enable_network_firewall ? local.vpcs : {}

  destination_cidr_block         = each.value.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

# Cost-conscious lab mode: when Network Firewall is disabled, route directly.
resource "aws_ec2_transit_gateway_route" "direct_to_spoke" {
  for_each = var.enable_network_firewall ? {} : local.vpcs

  destination_cidr_block         = each.value.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ingress.id
}

