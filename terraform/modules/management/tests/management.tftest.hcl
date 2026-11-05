# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {}

variables {
  name         = "alz-mgmt-uks"
  location     = "uksouth"
  alert_emails = ["platform-team@example.co.uk", "on-call@example.co.uk"]
}

run "workspace_uses_entra_auth_only" {
  command = plan

  assert {
    condition     = !azurerm_log_analytics_workspace.this.local_authentication_enabled
    error_message = "Agents and queries must authenticate with Entra ID, not workspace keys."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.allow_resource_only_permissions
    error_message = "Teams must be able to query logs of resources they can read."
  }
}

run "one_receiver_per_address" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_action_group.platform.email_receiver) == 2
    error_message = "Every platform address receives alerts."
  }
}

run "retention_is_bounded" {
  command = plan

  variables {
    retention_in_days = 7
  }

  expect_failures = [var.retention_in_days]
}
