# 0003. Central privatelink DNS, resolved through the firewall

Status: accepted

## Context

A private endpoint only works if clients resolve the service name to its
private IP. If each landing zone links its own privatelink zones, the same
service resolves differently from different places, on-premises cannot
resolve it at all, and zones are duplicated.

## Decision

- Every `privatelink.*` zone exists once, in the connectivity subscription,
  linked only to the hub.
- Spoke VNets use the hub firewall as DNS server. The firewall's DNS proxy
  forwards to the DNS Private Resolver's inbound endpoint, which answers from
  the zones linked to the hub. FQDN-based firewall rules therefore see the
  same answers as the workloads.
- The resolver's outbound endpoint forwards on-premises domains; on-premises
  forwards Azure names to the inbound endpoint, which has a fixed address.

## Consequences

- Landing zones need the zone IDs (an output) for their private endpoints' DNS
  zone groups, and rights to write records in them. The next step is the CAF
  pattern of DeployIfNotExists policies that create the records, so teams need
  no rights on the zones at all.
- Sandboxes are not connected and use Azure DNS.
