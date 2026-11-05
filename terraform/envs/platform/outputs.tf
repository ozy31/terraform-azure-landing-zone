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

output "policy_assignment_ids" {
  description = "Policy assignment IDs, for exemptions."
  value       = module.policy.assignment_ids
}
