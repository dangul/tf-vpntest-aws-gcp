# tf-vpntest-aws-gcp

Test/lab project that builds a **VPN tunnel (IPsec + BGP)** between **AWS** and **GCP** using Terraform.

## What it creates

### AWS side
- VPC (`10.10.0.0/24`) with subnet
- Virtual Private Gateway (VGW)
- Customer Gateway (pointing at GCP's HA VPN gateway)
- VPN Connection (IPsec, BGP over tunnel 1)
- Route table with route propagation so the VPC learns the GCP network via BGP

### GCP side
- VPC network with subnet (`10.20.0.0/24`)
- HA VPN Gateway
- Cloud Router with BGP (ASN 65020)
- VPN tunnel to AWS (IKEv2) with shared secret from AWS
- Firewall rules for ICMP/SSH from the AWS network (for testing the connection)

### Tunnel / BGP
- Tunnel inside CIDR: `169.254.10.0/30` (AWS gets `.1`, GCP gets `.2`)
- AWS ASN: `65010`, GCP ASN: `65020`

## Requirements

- Terraform >= 1.x
- AWS credentials (e.g. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in the environment or `~/.aws/credentials`)
- A GCP project with appropriate permissions (e.g. `roles/compute.admin`) and credentials via `GOOGLE_APPLICATION_CREDENTIALS` or `gcloud auth application-default login`

## Getting started

```bash
git clone <repo-url>
cd tf-vpntest-aws-gcp

# Create your variables (fill in e.g. gcp_project)
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Useful outputs after `apply`:

```bash
terraform output   # shows VPN IPs and BGP IPs
```

## Tearing everything down

```bash
terraform destroy
```

## File structure

| File                          | Content                                                              |
|-------------------------------|----------------------------------------------------------------------|
| `main.tf`                     | All infrastructure (VPCs, VPN gateways, tunnels, BGP, firewalls)     |
| `variables.tf`                | Input variables with defaults                                        |
| `outputs.tf`                  | Outputs (VPN IPs, BGP IPs)                                           |
| `terraform.tfvars.example`    | Example variable values                                              |
| `.terraform.lock.hcl`         | Locked provider versions                                             |

## Notes

- `terraform.tfvars` and state files (`*.tfstate*`) are **gitignored** – never commit secrets to the repo.
- State is kept locally by default. For real teams/projects you should use a remote backend (e.g. S3 + DynamoDB).
- This is a lab project for learning how VPNs between AWS and GCP work – not a production solution.
