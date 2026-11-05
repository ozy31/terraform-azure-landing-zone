output "assignment_ids" {
  description = "Policy assignment IDs, for exemptions and compliance queries."
  value = merge(
    { for k, a in azurerm_management_group_policy_assignment.this : k => a.id },
    { for k, a in azurerm_management_group_policy_assignment.inherit_tag : "inherit-tag-${k}" => a.id },
  )
}

output "custom_definition_ids" {
  description = "Custom policy definition IDs, keyed by file name."
  value       = { for k, d in azurerm_policy_definition.custom : k => d.id }
}
