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

mock_provider "azurerm" {
  alias = "connectivity"

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/mock"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/publicIPAddresses/mock"
    }
  }

  mock_resource "azurerm_firewall_policy" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/firewallPolicies/afwp-alz-hub-uks"
    }
  }

  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks"
    }
  }
}

# Firewall and Bastion check the subnet name inside the subnet ID.
override_resource {
  target = module.hub.azurerm_subnet.this["AzureFirewallSubnet"]
  values = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/AzureFirewallSubnet"
  }
}

override_resource {
  target = module.hub.azurerm_subnet.this["AzureBastionSubnet"]
  values = {
    id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/AzureBastionSubnet"
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

run "hub_is_in_the_connectivity_subscription" {
  command = apply

  assert {
    condition     = startswith(module.hub.vnet_id, "/subscriptions/${var.connectivity_subscription_id}/")
    error_message = "The hub belongs to the connectivity subscription."
  }
}
