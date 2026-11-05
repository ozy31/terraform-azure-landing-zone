# terraform-azure-landing-zone

[![ci](https://github.com/ozy31/terraform-azure-landing-zone/actions/workflows/ci.yml/badge.svg)](https://github.com/ozy31/terraform-azure-landing-zone/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.9-7B42BC?logo=terraform)
![azurerm](https://img.shields.io/badge/azurerm-v5-0078D4?logo=microsoftazure)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

An Azure landing zone in Terraform, following the Cloud Adoption Framework:
the management group hierarchy, policy, a hub network and subscription
vending that application platforms such as
[terraform-azure-aks-platform](https://github.com/ozy31/terraform-azure-aks-platform)
are built on.

> Region, IDs and names are placeholders (UK South). Everything is validated in
> CI without an Azure subscription: Terraform tests use mocked providers.

## Management groups

```
alz                     Retail
├── alz-platform
│   ├── alz-connectivity    hub network, firewall, DNS
│   ├── alz-management      logging, Terraform state
│   └── alz-identity
├── alz-landing-zones
│   ├── alz-corp            private workloads, connected to the hub
│   └── alz-online          internet-facing workloads
├── alz-sandbox             experiments, not connected
└── alz-decommissioned
```

## Repository layout

```
terraform/
  modules/
    management-groups/  CAF hierarchy and platform subscription placement (+ tests)
  envs/platform/        composition for the whole tenant (+ tests)
```

## Validation

| Target | What it checks |
|---|---|
| `make terraform` | `fmt`, `init` and `validate` for every module and environment |
| `make tftest` | `terraform test` with mocked providers |
| `make tflint` | tflint with the azurerm ruleset |
| `make lint security` | yamllint, trivy |

## License

MIT
