# tf-vpntest-aws-gcp

Test-/labbprojekt som bygger en **VPN-tunnel (IPsec + BGP)** mellan **AWS** och **GCP** med Terraform.

## Vad som skapas

### AWS-sidan
- VPC (`10.10.0.0/24`) med subnät
- Virtual Private Gateway (VGW)
- Customer Gateway (pekar mot GCP:s HA VPN-gateway)
- VPN Connection (IPsec, BGP via tunnel 1)
- Route table med route propagation så att VPC:n lär sig GCP-nätet via BGP

### GCP-sidan
- VPC-nätverk med subnät (`10.20.0.0/24`)
- HA VPN Gateway
- Cloud Router med BGP (ASN 65020)
- VPN-tunnel mot AWS (IKEv2) med delad hemlighet från AWS
- Brandväggsregler för ICMP/SSH från AWS-nätet (för test av anslutningen)

### Tunnel / BGP
- Tunnel inside-CIDR: `169.254.10.0/30` (AWS får `.1`, GCP får `.2`)
- AWS ASN: `65010`, GCP ASN: `65020`

## Krav

- Terraform >= 1.x
- AWS-credentials (t.ex. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` i miljön eller `~/.aws/credentials`)
- GCP-projekt med lämpliga rättigheter (t.ex. `roles/compute.admin`) samt credentials via `GOOGLE_APPLICATION_CREDENTIALS` eller `gcloud auth application-default login`

## Kom igång

```bash
git clone <repo-url>
cd tf-vpntest-aws-gcp

# Skapa dina variabler (fyll i t.ex. gcp_project)
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Användbara outputs efter `apply`:

```bash
terraform output          # visar VPN-IP:er och BGP-IP:er
```

## Ta bort allt

```bash
terraform destroy
```

## Filstruktur

| Fil                          | Innehåll                                   |
|------------------------------|--------------------------------------------|
| `main.tf`                    | All infrastruktur (VPC, VPN-gateways, tunnlar, BGP, brandväggar) |
| `variables.tf`               | Indatavariabler med defaults               |
| `outputs.tf`                 | Outputs (VPN-IP:er, BGP-IP:er)             |
| `terraform.tfvars.example`   | Exempel på variabelvärden                  |
| `.terraform.lock.hcl`        | Låst provider-versioner                    |

## Noteringar

- `terraform.tfvars` och statefiler (`*.tfstate*`) är **gitignorerade** – lägg aldrig in hemligheter i repot.
- State ligger lokalt som standard. För riktiga team/projekt bör du använda en remote backend (t.ex. S3 + DynamoDB).
- Detta är ett labb för att lära sig hur VPN mellan AWS och GCP funkar – inte en produktionslösning.
