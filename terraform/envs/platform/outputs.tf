output "management_group_ids" {
  description = "Management group IDs, for assignments made outside this repository."
  value       = module.management_groups.ids
}

output "policy_assignment_ids" {
  description = "Policy assignment IDs, for exemptions."
  value       = module.policy.assignment_ids
}
