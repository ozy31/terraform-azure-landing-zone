# 0005. Corp and online archetypes

Status: accepted

## Context

Most workloads should have no public endpoints and egress only through the
firewall. Some must be reachable from the internet, and forcing their egress
through the firewall breaks them: replies to traffic that arrived on a public
load balancer would leave through the firewall and be dropped (asymmetric
routing).

## Decision

| | corp | online |
|---|---|---|
| Public IPs | denied by policy | allowed |
| Default route | hub firewall | own egress (NAT gateway) |
| Egress control | per-landing-zone FQDN rules on the firewall | inside the workload (network policy, NAT gateway IPs) |
| Hub peering, central DNS | yes | yes |

The AKS platform (terraform-azure-aks-platform) is online: public ingress
through its own load balancer, egress through a NAT gateway with fixed IPs,
and in-cluster network policy. It is still peered for private endpoints and
on-premises.

## Consequences

- Moving a workload from online to corp is a management group move plus a
  route table, and is denied while it still has public IPs.
- An online landing zone that later needs inspected egress can add a route to
  the firewall for specific prefixes without a forced tunnel.
