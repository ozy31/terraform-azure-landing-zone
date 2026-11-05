# 0001. CAF management groups, with policy assigned only to groups

Status: accepted

## Context

Guardrails assigned to single subscriptions drift: each new subscription has
to be remembered, and two subscriptions of the same kind end up with
different rules. Teams also need to know, before they build, which rules
apply to them.

## Decision

- Use the Cloud Adoption Framework hierarchy: platform (connectivity,
  management, identity), landing-zones (corp, online), sandbox,
  decommissioned.
- Assign policy to management groups only. A subscription's guardrails follow
  from where it is placed, and moving it (to decommissioned, say) changes them.
- Keep custom definitions as JSON files in the portal export shape, defined at
  the root group so any assignment below can use them.
- Roll out new guardrails audit-only (`DoNotEnforce`) and enforce them once the
  compliance view is clean.

## Consequences

- Management group IDs are tenant-wide and cannot be renamed, hence the short
  `alz` prefix fixed at the start.
- An exception for one workload is a policy exemption with an expiry date,
  not a different assignment.
