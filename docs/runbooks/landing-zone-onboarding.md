# Onboarding a landing zone

## Before the pull request

| Question | Decides |
|---|---|
| Must it be reachable from the internet? | `online`, otherwise `corp` |
| Experiment with no corporate data or connectivity? | `sandbox` |
| Existing subscription or a new one? | `subscriptionId` or `billingScopeId` |
| How many addresses in five years? | `addressSpace` (a /22 is 1,019 hosts after Azure's 5 per subnet) |
| Which external services (corp)? | `egressFqdns` |

## Pull request

1. Add `landing-zones/<name>.yaml` (see `payments.yaml`). The name becomes
   part of every resource name: 3-24 lowercase characters.
2. Pick an `addressSpace` from the spoke supernet (`10.0.0.0/10`) that is not
   used; CI fails on an overlap. For corp, pick a `firewallPriority` that is
   not used, in steps of 10 from 1010.
3. CI runs the checks and `terraform plan` shows what will be created.

## After merge

- The subscription moves under its management group: its policies apply from
  then on.
- The team creates its subnets in the VNet, each with the vended NSG (and,
  for corp, the route table) attached. Policy audits subnets without an NSG.
- Private endpoints use the central zones (`private_dns_zone_ids` output).
- The budget emails the contacts at 80% of actual spend and 100% of forecast.

## Decommissioning

1. Set `archetype: decommissioned`. The subscription moves to
   `alz-decommissioned`, where policy allows nothing new, and loses its hub
   peering, DNS and firewall rules. Its address space is free again.
2. When the team confirms it is empty, delete the YAML file. Terraform removes
   the VNet, budget and role assignment. A subscription created through an
   alias is protected by `prevent_destroy` and is cancelled by hand.
