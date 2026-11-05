output "management_group_ids" {
  description = "Management group IDs, for assignments made outside this repository."
  value       = module.management_groups.ids
}
