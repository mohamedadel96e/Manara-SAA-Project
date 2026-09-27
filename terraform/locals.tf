locals {
  common_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Purpose   = "SAA hybrid connectivity lab"
    },
    var.tags,
  )

  vpcs = {
    dev = {
      cidr        = var.vpc_cidrs.dev
      environment = "Development"
    }
    staging = {
      cidr        = var.vpc_cidrs.staging
      environment = "Staging"
    }
    prod = {
      cidr        = var.vpc_cidrs.prod
      environment = "Production"
    }
    shared = {
      cidr        = var.vpc_cidrs.shared
      environment = "SharedServices"
    }
  }

  private_subnets = merge([
    for vpc_key, vpc in local.vpcs : {
      for az_index in range(2) : "${vpc_key}-${az_index}" => {
        vpc_key  = vpc_key
        az_index = az_index
        cidr     = cidrsubnet(vpc.cidr, 8, az_index)
      }
    }
  ]...)

  shared_subnet_keys = [
    for key, subnet in local.private_subnets : key
    if subnet.vpc_key == "shared"
  ]

  aws_cidrs       = [for vpc in values(local.vpcs) : vpc.cidr]
  connected_cidrs = concat(local.aws_cidrs, [var.on_prem_cidr])

  firewall_attachment_id = var.enable_network_firewall ? one(
    aws_networkfirewall_firewall.central[0].firewall_status[0].transit_gateway_attachment_sync_states[*].attachment_id
  ) : null
}

