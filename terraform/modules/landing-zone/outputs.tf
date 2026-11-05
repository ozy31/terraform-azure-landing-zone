output "subscription_id" {
  description = "Landing zone subscription ID."
  value       = local.subscription_id
}

output "vnet_id" {
  description = "Spoke VNet ID. The team creates its subnets here."
  value       = azapi_resource.vnet.id
}

output "nsg_id" {
  description = "Default NSG for the team's subnets."
  value       = azapi_resource.nsg.id
}

output "route_table_id" {
  description = "Corp only: route table sending 0.0.0.0/0 to the hub firewall. Attach it to every subnet."
  value       = local.corp ? azapi_resource.route_table[0].id : null
}
