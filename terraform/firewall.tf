resource "aws_networkfirewall_rule_group" "hybrid" {
  count = var.enable_network_firewall ? 1 : 0

  capacity = 100
  name     = "${var.project_name}-hybrid-allowlist"
  type     = "STATEFUL"

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = local.connected_cidrs
        }
      }
    }

    rules_source {
      rules_string = <<-RULES
        pass icmp $HOME_NET any -> $HOME_NET any (msg:"Allow hybrid ICMP"; sid:1001; rev:1;)
        pass udp $HOME_NET any -> $HOME_NET 53 (msg:"Allow hybrid DNS over UDP"; sid:1002; rev:1;)
        pass tcp $HOME_NET any -> $HOME_NET 53 (msg:"Allow hybrid DNS over TCP"; sid:1003; rev:1;)
        pass tcp $HOME_NET any -> $HOME_NET 443 (msg:"Allow hybrid HTTPS"; sid:1004; rev:1;)
      RULES
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = {
    Name = "${var.project_name}-hybrid-allowlist"
  }
}

resource "aws_networkfirewall_firewall_policy" "central" {
  count = var.enable_network_firewall ? 1 : 0

  name = "${var.project_name}-central-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_default_actions           = ["aws:drop_strict", "aws:alert_strict"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 100
      resource_arn = aws_networkfirewall_rule_group.hybrid[0].arn
    }
  }

  tags = {
    Name = "${var.project_name}-central-policy"
  }
}

resource "aws_networkfirewall_firewall" "central" {
  count = var.enable_network_firewall ? 1 : 0

  name                = "${var.project_name}-central"
  description         = "Transit Gateway-attached firewall for hybrid and east-west inspection"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.central[0].arn
  transit_gateway_id  = aws_ec2_transit_gateway.hub.id

  dynamic "availability_zone_mapping" {
    for_each = slice(data.aws_availability_zones.available.zone_ids, 0, 2)
    content {
      availability_zone_id = availability_zone_mapping.value
    }
  }

  tags = {
    Name = "${var.project_name}-central"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "firewall_inspection" {
  count = var.enable_network_firewall ? 1 : 0

  transit_gateway_attachment_id  = local.firewall_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_cloudwatch_log_group" "firewall_alert" {
  count = var.enable_network_firewall ? 1 : 0

  name              = "/aws/network-firewall/${var.project_name}/alert"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  count = var.enable_network_firewall ? 1 : 0

  name              = "/aws/network-firewall/${var.project_name}/flow"
  retention_in_days = 30
}

resource "aws_networkfirewall_logging_configuration" "central" {
  count = var.enable_network_firewall ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.central[0].arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alert[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flow[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}

