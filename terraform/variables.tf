variable "project_name" {
  description = "Short name used in resource names and tags."
  type        = string
  default     = "hybrid-tgw-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.project_name))
    error_message = "project_name must contain 3-24 lowercase letters, numbers, or hyphens."
  }
}

variable "aws_region" {
  description = "AWS Region in which to deploy the regional network."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidrs" {
  description = "Non-overlapping CIDR ranges for the AWS environments."
  type = object({
    dev     = string
    staging = string
    prod    = string
    shared  = string
  })
  default = {
    dev     = "10.10.0.0/16"
    staging = "10.20.0.0/16"
    prod    = "10.30.0.0/16"
    shared  = "10.100.0.0/16"
  }
}

variable "on_prem_cidr" {
  description = "CIDR advertised by the on-premises router over BGP. It must not overlap any VPC CIDR."
  type        = string
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrhost(var.on_prem_cidr, 0))
    error_message = "on_prem_cidr must be a valid IPv4 CIDR."
  }
}

variable "customer_gateway_public_ip" {
  description = "Static public IPv4 address of the physical or virtual on-premises VPN router. Replace the documentation address before applying."
  type        = string
  default     = "203.0.113.10"

  validation {
    condition     = can(cidrhost("${var.customer_gateway_public_ip}/32", 0))
    error_message = "customer_gateway_public_ip must be a valid IPv4 address."
  }
}

variable "customer_gateway_bgp_asn" {
  description = "Private ASN configured on the customer gateway device."
  type        = number
  default     = 65000

  validation {
    condition     = var.customer_gateway_bgp_asn >= 64512 && var.customer_gateway_bgp_asn <= 65534
    error_message = "Use a private 16-bit ASN between 64512 and 65534 for this lab."
  }
}

variable "transit_gateway_bgp_asn" {
  description = "Private ASN used by the AWS Transit Gateway. It must differ from the customer ASN."
  type        = number
  default     = 64512

  validation {
    condition     = var.transit_gateway_bgp_asn >= 64512 && var.transit_gateway_bgp_asn <= 65534
    error_message = "Use a private 16-bit ASN between 64512 and 65534 for this lab."
  }
}

variable "private_aws_domain" {
  description = "Private Route 53 hosted-zone name resolved from AWS and on premises."
  type        = string
  default     = "aws.example.internal"
}

variable "on_prem_domain" {
  description = "On-premises DNS suffix that AWS Resolver forwards to the data-center DNS servers."
  type        = string
  default     = "corp.example.internal"
}

variable "on_prem_dns_ips" {
  description = "One or more DNS server IP addresses reachable inside on_prem_cidr."
  type        = list(string)
  default     = ["172.16.10.10"]

  validation {
    condition     = length(var.on_prem_dns_ips) > 0 && alltrue([for ip in var.on_prem_dns_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "Provide at least one valid IPv4 DNS server address."
  }
}

variable "enable_network_firewall" {
  description = "Create a Transit Gateway-attached AWS Network Firewall and steer hybrid/east-west traffic through it. This has a material hourly cost."
  type        = bool
  default     = true
}

variable "ram_principal_arns" {
  description = "Optional AWS Organizations, OU, or account ARNs with which to share the Transit Gateway using AWS RAM."
  type        = set(string)
  default     = []
}

variable "audit_log_retention_days" {
  description = "Number of days before audit objects expire from the lab bucket."
  type        = number
  default     = 365

  validation {
    condition     = var.audit_log_retention_days >= 90
    error_message = "Keep audit logs for at least 90 days in this lab."
  }
}

variable "tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}

