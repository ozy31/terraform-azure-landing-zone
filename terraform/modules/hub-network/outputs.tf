output "resource_group_name" {
  description = "Hub resource group."
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "Hub VNet ID, the remote end of every spoke peering."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Hub VNet name."
  value       = azurerm_virtual_network.this.name
}

output "firewall_private_ip" {
  description = "Next hop for spoke default routes, and the DNS server spokes use."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Egress IP of every corp landing zone, for partner allow-lists."
  value       = azurerm_public_ip.firewall.ip_address
}

output "firewall_dns_servers" {
  description = "Upstream servers of the firewall DNS proxy."
  value       = azurerm_firewall_policy.this.dns[0].servers
}

output "firewall_policy_id" {
  description = "Firewall policy that landing zone rule collection groups attach to."
  value       = azurerm_firewall_policy.this.id
}
