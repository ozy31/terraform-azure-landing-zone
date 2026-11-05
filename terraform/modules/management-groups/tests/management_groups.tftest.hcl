# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
  mock_resource "azurerm_management_group" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/mock"
    }
  }
}

variables {
  root_display_name          = "Retail"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000000"
  subscription_placement = {
    "11111111-1111-1111-1111-111111111111" = "connectivity"
    "22222222-2222-2222-2222-222222222222" = "management"
  }
}

run "caf_hierarchy" {
  command = apply

  assert {
    condition     = toset(keys(output.ids)) == toset(["root", "platform", "landing-zones", "sandbox", "decommissioned", "connectivity", "management", "identity", "corp", "online"])
    error_message = "The hierarchy must contain every CAF management group."
  }

  assert {
    condition     = azurerm_management_group.level2["corp"].parent_management_group_id == "/providers/Microsoft.Management/managementGroups/alz-landing-zones"
    error_message = "corp belongs under landing-zones."
  }

  assert {
    condition     = azurerm_management_group.level2["connectivity"].parent_management_group_id == "/providers/Microsoft.Management/managementGroups/alz-platform"
    error_message = "connectivity belongs under platform."
  }
}

run "platform_subscriptions_are_placed" {
  command = apply

  assert {
    condition     = azurerm_management_group_subscription_association.this["11111111-1111-1111-1111-111111111111"].subscription_id == "/subscriptions/11111111-1111-1111-1111-111111111111"
    error_message = "Subscriptions are associated by resource ID."
  }

  assert {
    condition     = azurerm_management_group_subscription_association.this["22222222-2222-2222-2222-222222222222"].management_group_id == output.ids["management"]
    error_message = "The management subscription goes into the management group."
  }
}

run "unknown_management_group_is_rejected" {
  command = plan

  variables {
    subscription_placement = { "11111111-1111-1111-1111-111111111111" = "prod" }
  }

  expect_failures = [var.subscription_placement]
}
