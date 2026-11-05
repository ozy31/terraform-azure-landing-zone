# Platform logs into the central workspace, and alerts on the shared hub.

locals {
  platform_subscription_ids = toset([
    var.management_subscription_id,
    var.connectivity_subscription_id,
    var.identity_subscription_id,
  ])
}

# Activity log of each platform subscription: who changed what in the
# control plane, policy denials, service health. Landing zone subscriptions
# get the same setting from the vending module.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  for_each = local.platform_subscription_ids

  name                       = "activity-to-log-analytics"
  target_resource_id         = "/subscriptions/${each.key}"
  log_analytics_workspace_id = module.management.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(["Administrative", "Security", "Policy", "ServiceHealth", "Alert", "ResourceHealth"])

    content {
      category = enabled_log.value
    }
  }
}

# Resource-specific tables (AZFWApplicationRule, AZFWNetworkRule, AZFWDnsQuery,
# ...) are cheaper to query and keep than the single AzureDiagnostics table.
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  provider = azurerm.connectivity

  name                           = "diag-to-log-analytics"
  target_resource_id             = module.hub.firewall_id
  log_analytics_workspace_id     = module.management.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  provider = azurerm.connectivity

  name                       = "diag-to-log-analytics"
  target_resource_id         = module.hub.bastion_id
  log_analytics_workspace_id = module.management.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }
}

# Every corp landing zone egresses through this firewall: an unhealthy
# firewall or SNAT exhaustion is an outage for all of them.
resource "azurerm_monitor_metric_alert" "firewall" {
  provider = azurerm.connectivity
  for_each = {
    health = { metric = "FirewallHealth", aggregation = "Average", operator = "LessThan", threshold = 90, severity = 1, description = "Azure Firewall health below 90%." }
    snat   = { metric = "SNATPortUtilization", aggregation = "Maximum", operator = "GreaterThan", threshold = 80, severity = 2, description = "Firewall SNAT port use above 80%: add public IPs or a NAT gateway on AzureFirewallSubnet." }
  }

  name                = "alert-${module.hub.firewall_name}-${each.key}"
  resource_group_name = module.hub.resource_group_name
  scopes              = [module.hub.firewall_id]
  description         = each.value.description
  severity            = each.value.severity
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = each.value.metric
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = module.management.action_group_id
  }
}
