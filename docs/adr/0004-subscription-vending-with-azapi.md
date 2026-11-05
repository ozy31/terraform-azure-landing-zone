# 0004. Subscription vending with azapi and one YAML file per landing zone

Status: accepted

## Context

A landing zone touches several subscriptions: its own, the connectivity
subscription (hub peering, firewall rules) and the tenant (management group,
subscription alias). With azurerm, each subscription needs its own provider
block, and provider blocks cannot be created with `for_each`.

## Decision

- The landing-zone module uses `azapi` only. Every resource is addressed by
  its full resource ID, so one provider reaches any subscription the pipeline
  identity has rights on. This is the approach of the Azure Verified Module for
  landing zone vending.
- Each landing zone is `landing-zones/<name>.yaml`, reviewed as a pull request;
  the platform root reads every file and calls the module once per file.
- What Terraform cannot check across files (address overlaps, firewall
  priorities) is checked by `hack/check-landing-zones.py` in CI.

## Consequences

- No schema checking from azurerm: azapi validates request bodies against the
  embedded API schemas at plan time instead, and API versions are explicit.
- Hub peerings and firewall rule collection groups take `locks` on the hub VNet
  and firewall policy, since Azure rejects concurrent changes to them.
- The VNet ignores `subnets` and the NSG ignores `securityRules`: those belong
  to the team, and the next apply must not remove them.
