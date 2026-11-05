# Central logging for the platform: one Log Analytics workspace in the
# management subscription for activity logs, firewall and Bastion logs, and
# an action group the platform alerts go to. Landing zones send their own
# resource logs to their own workspaces; only control-plane logs come here.

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags

  # Access by workspace RBAC or by the caller's rights on the source resource,
  # so a landing zone team can query its own subscription's activity log.
  allow_resource_only_permissions = true
  local_authentication_enabled    = false
}

resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-${var.name}-platform"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "platform"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = toset(var.alert_emails)

    content {
      name                    = "email-${index(var.alert_emails, email_receiver.value)}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}
