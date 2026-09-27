resource "aws_ram_resource_share" "transit_gateway" {
  count = length(var.ram_principal_arns) > 0 ? 1 : 0

  name                      = "${var.project_name}-transit-gateway"
  allow_external_principals = false

  tags = {
    Name = "${var.project_name}-transit-gateway"
  }
}

resource "aws_ram_resource_association" "transit_gateway" {
  count = length(var.ram_principal_arns) > 0 ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.hub.arn
  resource_share_arn = aws_ram_resource_share.transit_gateway[0].arn
}

resource "aws_ram_principal_association" "transit_gateway" {
  for_each = var.ram_principal_arns

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.transit_gateway[0].arn
}

