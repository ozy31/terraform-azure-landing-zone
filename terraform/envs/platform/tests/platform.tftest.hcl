# Wiring tests for the platform root module. Providers are mocked, so this
# runs in CI without Azure credentials; terraform.tfvars supplies the inputs.
mock_provider "azurerm" {
  mock_resource "azurerm_management_group" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/mock"
    }
  }

  mock_data "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    }
  }

  mock_resource "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/alz/providers/Microsoft.Authorization/policyDefinitions/mock"
    }
  }

  mock_resource "azurerm_management_group_policy_set_definition" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/alz/providers/Microsoft.Authorization/policySetDefinitions/lz-baseline"
    }
  }
}

run "platform_subscriptions_sit_in_platform_groups" {
  command = apply

  assert {
    condition     = module.management_groups.ids["root"] == "/providers/Microsoft.Management/managementGroups/alz"
    error_message = "The hierarchy hangs off the tenant root group as alz."
  }
}

run "policy_uses_this_hierarchy" {
  command = apply

  assert {
    condition     = module.policy.assignment_ids["corp-deny-public-ip"] != null && module.policy.custom_definition_ids["deny-public-ip"] != null
    error_message = "The corp public IP guardrail must be assigned."
  }
}
