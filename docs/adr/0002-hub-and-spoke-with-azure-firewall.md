# 0002. Hub and spoke with Azure Firewall, not Virtual WAN

Status: accepted

## Context

Spokes need central egress control, shared DNS, and later a connection to
on-premises. Azure offers a customer-managed hub VNet or Virtual WAN with a
secured virtual hub.

## Decision

A customer-managed hub VNet in the connectivity subscription with Azure
Firewall (Standard, Premium where TLS inspection or IDPS is needed), Bastion,
the DNS Private Resolver, and a GatewaySubnet kept free.

## Why not Virtual WAN

- One region and a handful of spokes: Virtual WAN's value is any-to-any
  routing across many regions and branches.
- A hub VNet can host the resolver and other shared services directly; a
  virtual hub cannot.
- Routing stays visible as route tables in Terraform, which is easier to
  review and debug than routing intent.

Revisit when a second region or many branch sites arrive.

## Consequences

- Corp spokes carry a route table with 0.0.0.0/0 to the firewall and
  `disableBgpRoutePropagation`, so routes learned by a future gateway cannot
  bypass it.
- The firewall is shared: its health and SNAT use are alerted on, and its
  rule changes are serialised (azapi `locks`).
