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

## Hub network

```mermaid
flowchart LR
    subgraph hub["connectivity subscription: hub VNet 10.100.0.0/22"]
        afw["Azure Firewall<br/>DNS proxy, threat intel deny"]
        bas["Bastion (Standard)"]
        gw["GatewaySubnet<br/>reserved for VPN / ExpressRoute"]
        dnspr["DNS Private Resolver<br/>inbound 10.100.0.164"]
        zones["privatelink zones"]
    end
    afw -- "DNS proxy" --> dnspr --> zones
    dnspr -- "forwarding rules" --> onprem["on-premises DNS"]
    internet(("internet"))
    afw --> internet
    admins["admins"] --> bas
```

- **Azure Firewall** with a firewall policy: platform rules (NTP, Windows
  Update, Azure Monitor) at priority 200, one rule collection group per landing
  zone above 1000. Threat intelligence in Deny mode; Premium adds IDPS.
- **DNS proxy on the firewall**, so FQDN rules resolve the same addresses as the
  workloads behind it.
- **Central DNS.** Every `privatelink` zone lives once, in the connectivity
  subscription, linked to the hub. Spokes use the firewall as DNS server; the
  firewall proxies to a DNS Private Resolver, which answers from those zones and
  forwards on-premises domains. On-premises forwards Azure names to the
  resolver's fixed inbound address.
- **Bastion Standard** with native client tunnelling: no public IPs on VMs.
- **GatewaySubnet** kept free, so adding VPN or ExpressRoute does not mean
  re-addressing the hub.

## Landing zones

[`modules/landing-zone`](terraform/modules/landing-zone) is subscription
vending: one module call gives a team a ready subscription.

| | corp | online | sandbox |
|---|---|---|---|
| Management group | alz-corp | alz-online | alz-sandbox |
| Hub peering (both ways) | yes | yes | no |
| DNS through the hub | yes | yes | no |
| 0.0.0.0/0 to the firewall | yes | no, own egress | no |
| Firewall rule group for its FQDNs | yes | no | no |

A team asks for one with a pull request adding `landing-zones/<name>.yaml`:

```yaml
archetype: corp
subscriptionId: 44444444-4444-4444-4444-444444444444   # or billingScopeId: to create one
addressSpace: 10.1.0.0/22
ownerGroupId: 2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10    # Entra group
costCenter: CC-2001
budget:
  amount: 3000
  contacts: [payments-team@example.co.uk]
firewallPriority: 1010
egressFqdns: [api.stripe.com, "*.adyen.com"]
```

[`aks-platform.yaml`](landing-zones/aks-platform.yaml) is the landing zone of
[terraform-azure-aks-platform](https://github.com/ozy31/terraform-azure-aks-platform):
online, because its ingress has a public load balancer and its egress a NAT
gateway with fixed IPs, and peered to the hub for private endpoints and
on-premises. `make landing-zones` checks what Terraform cannot: connected
address spaces inside the spoke supernet and not overlapping each other or
the hub, and unique firewall priorities.

Every landing zone also gets its activity log in the central workspace, a
monthly budget with 80% actual and 100% forecast alerts, and the owning Entra
group as Contributor. The subscription is either existing or created from a
billing scope through a subscription alias.

It is written with `azapi`, so one provider reaches any subscription by
resource ID: a new landing zone needs no new provider block. Peerings and
firewall rule groups take a lock on the hub VNet and firewall policy, because
Azure rejects concurrent changes to them. The VNet ignores changes to
`subnets`, which belong to the team, with the NSG and route table vending
creates for them.

## Management

- One Log Analytics workspace in the management subscription for platform
  logs: activity logs of every subscription (landing zones included, through
  vending), firewall logs in resource-specific `AZFW*` tables, Bastion audit
  logs. Entra auth only, resource-context access so teams can query their own
  subscription's activity.
- Alerts on the shared hub, because a firewall problem is an outage for every
  corp landing zone: firewall health below 90%, SNAT port use above 80%.

```kusto
// Top denied egress destinations in the last hour
AZFWApplicationRule
| where TimeGenerated > ago(1h) and Action == "Deny"
| summarize count() by SourceIp, Fqdn
| top 20 by count_
```

## Policy

Assigned to management groups, so a subscription gets its guardrails from
where it is placed. Custom definitions are JSON files in
[`terraform/modules/policy/definitions`](terraform/modules/policy/definitions),
in the same shape as a portal export.

| Scope | Assignment | Effect |
|---|---|---|
| root | Allowed locations, for resources and resource groups (UK South, UK West) | Deny |
| root | `cost-center` tag on resource groups, inherited by resources | Deny, Modify |
| landing-zones | Landing zone baseline initiative: subnet NSG (custom), storage HTTPS only, Key Vault deletion protection, AKS local accounts disabled | Audit, then Deny |
| corp | No public IP addresses (custom) | Deny |
| sandbox | No ExpressRoute, VPN, Virtual WAN or peering | Deny |
| decommissioned | Nothing new but resource groups | Deny |

New guardrails go out audit-only first: list the assignment in
`policy_do_not_enforce`, check the compliance view, then remove it.

## Repository layout

```
terraform/
  modules/
    management-groups/  CAF hierarchy and platform subscription placement (+ tests)
    policy/             custom definitions (JSON), baseline initiative, assignments (+ tests)
    hub-network/        hub VNet, Azure Firewall and policy, Bastion (+ tests)
    private-dns/        central privatelink zones, DNS Private Resolver, forwarding (+ tests)
    management/         central Log Analytics workspace, platform action group (+ tests)
    landing-zone/       subscription vending with azapi: placement, spoke, peering, routes, budget (+ tests)
  envs/platform/        composition for the whole tenant (+ tests)
landing-zones/          one YAML file per landing zone
hack/                   cross-file checks for landing zones
```

## Validation

| Target | What it checks |
|---|---|
| `make terraform` | `fmt`, `init` and `validate` for every module and environment |
| `make tftest` | `terraform test` with mocked providers |
| `make tflint` | tflint with the azurerm ruleset |
| `make landing-zones` | address overlaps and firewall priorities across `landing-zones/*.yaml` |
| `make lint security` | yamllint, trivy |

## License

MIT
