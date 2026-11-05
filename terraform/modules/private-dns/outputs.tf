output "inbound_endpoint_ip" {
  description = "Resolver address for the firewall DNS proxy and on-premises conditional forwarders."
  value       = local.inbound_ip
}

output "private_dns_zone_ids" {
  description = "Central privatelink zone IDs keyed by zone name, for private endpoint DNS zone groups in any landing zone."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
