output "log_analytics_workspace_id" {
  description = "Central workspace for platform and activity logs."
  value       = azurerm_log_analytics_workspace.this.id
}

output "action_group_id" {
  description = "Action group for platform alerts."
  value       = azurerm_monitor_action_group.platform.id
}
