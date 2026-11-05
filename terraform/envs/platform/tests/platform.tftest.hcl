# Wiring tests for the platform root module. Providers are mocked, so this
# runs in CI without Azure credentials; terraform.tfvars supplies the inputs.
mock_provider "azurerm" {
  mock_resource "azurerm_management_group" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/mock"
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
