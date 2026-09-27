# Deployment and validation runbook

## Before deploying

You need:

- Terraform 1.8 or later
- AWS CLI v2
- an AWS account and credentials allowed to create the documented services
- a static, internet-routable public IPv4 address on the customer gateway
- a BGP-capable VPN router that supports IKEv2
- a corporate CIDR and DNS server that don't overlap the AWS ranges

Set an AWS Budget before starting. This project creates resources with hourly charges. Do not leave the lab running after you finish.

## Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and replace at least:

- `customer_gateway_public_ip`
- `customer_gateway_bgp_asn`
- `on_prem_cidr`
- `on_prem_dns_ips`
- both DNS suffixes

Run a CIDR overlap check using your organization's IPAM before deployment.

## Plan

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=hybrid.tfplan
```

Read the plan. Pay special attention to resource count, Region, CIDRs, RAM principals, and anything that creates recurring cost.

## Apply

```bash
terraform apply hybrid.tfplan
```

The firewall and Resolver endpoints can take several minutes to become available.

## Configure the customer gateway

Write the generated vendor-neutral configuration to a protected file:

```bash
terraform output -raw customer_gateway_configuration > customer-gateway-config.xml
chmod 600 customer-gateway-config.xml
```

Retrieve the PSKs only from an approved administrative session. The output `vpn_preshared_key_secret_arn` identifies the Secrets Manager secret. Translate the two AWS tunnel definitions into the vendor's router syntax, configure both BGP neighbors, and advertise only the approved on-premises prefixes.

Do not commit the XML, Terraform state, PSKs, or router configuration containing secrets. The repository ignores the common local paths, but the operator still owns secret handling.

## Configure on-premises DNS

1. Read `terraform output resolver_inbound_ips`.
2. Create a conditional forwarder for `private_aws_domain` to both inbound endpoint IPs.
3. Ensure the corporate firewall allows TCP and UDP 53 to those IPs across the VPN.
4. Confirm the AWS forwarding rule targets the correct corporate DNS addresses.

## Validation matrix

| Check | Method | Expected result |
| --- | --- | --- |
| Both VPN tunnels | VPC console, VPN logs, router status | Both IPsec and BGP sessions are up |
| BGP route exchange | TGW route table and router route table | Corporate CIDR and AWS prefixes appear as expected |
| Data center to Dev | ICMP to a temporary private test instance | Reply succeeds and Flow Logs record it |
| Data center to Prod on unapproved port | TCP probe to a temporary target | Network Firewall drops and alerts |
| AWS to corporate DNS | `dig host.corp.example.internal` | Corporate DNS returns the record |
| Corporate to AWS DNS | `dig connectivity.aws.example.internal` | TXT response is `hybrid-dns-ready` |
| Tunnel failure | Disable one customer tunnel | Traffic reconverges to the other tunnel |
| Audit | Change a test route, then inspect CloudTrail/Config | API event and configuration change are recorded |
| RAM | Inspect the intended member account | Shared Transit Gateway is visible to the approved principal |

Delete temporary test instances after validation.

## Troubleshooting order

1. Confirm IKE and IPsec tunnel state.
2. Confirm BGP state and received/advertised prefixes.
3. Check the VPC subnet route table.
4. Check the attachment's associated Transit Gateway route table.
5. Check the post-inspection route table and VPN propagation.
6. Check Network Firewall alert and flow logs.
7. Check security groups, network ACLs, and host firewalls.
8. Check Resolver rules and endpoint security-group logs/Flow Logs.

This order follows the packet path and avoids changing several layers at once.

## Destroy

```bash
terraform destroy
```

Confirm that the VPN, Network Firewall, Resolver endpoints, Transit Gateway attachments, Transit Gateway, log groups, and audit bucket are gone. An S3 bucket containing audit objects can prevent deletion; retain or remove those records according to your policy rather than bypassing retention casually.

