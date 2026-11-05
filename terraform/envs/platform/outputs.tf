output "management_group_ids" {
  description = "Management group IDs, for assignments made outside this repository."
  value       = module.management_groups.ids
}

output "hub_vnet_id" {
  description = "Hub VNet ID."
  value       = module.hub.vnet_id
}

output "egress_ip" {
  description = "Public IP that corp landing zones egress from."
  value       = module.hub.firewall_public_ip
}

output "dns_resolver_ip" {
  description = "Point on-premises conditional forwarders for Azure privatelink zones here."
  value       = module.dns.inbound_endpoint_ip
}

output "private_dns_zone_ids" {
  description = "Central privatelink zones, for private endpoints in any landing zone."
  value       = module.dns.private_dns_zone_ids
}

output "log_analytics_workspace_id" {
  description = "Central platform workspace."
  value       = module.management.log_analytics_workspace_id
}

output "policy_assignment_ids" {
  description = "Policy assignment IDs, for exemptions."
  value       = module.policy.assignment_ids
}
