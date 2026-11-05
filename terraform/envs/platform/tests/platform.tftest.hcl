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

  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-alz-mgmt-uks/providers/Microsoft.OperationalInsights/workspaces/log-alz-mgmt-uks"
    }
  }

  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-alz-mgmt-uks/providers/Microsoft.Insights/actionGroups/ag-alz-mgmt-uks-platform"
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

  mock_resource "azurerm_firewall" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/azureFirewalls/afw-alz-hub-uks"
    }
  }

  mock_resource "azurerm_bastion_host" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/bastionHosts/bas-alz-hub-uks"
    }
  }

  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/privateDnsZones/mock"
    }
  }

  mock_resource "azurerm_private_dns_resolver" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsResolvers/dnspr-alz-hub-uks"
    }
  }

  mock_resource "azurerm_private_dns_resolver_outbound_endpoint" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsResolvers/dnspr-alz-hub-uks/outboundEndpoints/out"
    }
  }

  mock_resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" {
    defaults = {
      id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-alz-hub-uks"
    }
  }
}

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock"
      output = { properties = { subscriptionId = "77777777-7777-7777-7777-777777777777" } }
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

  assert {
    condition     = module.hub.firewall_dns_servers == tolist([module.dns.inbound_endpoint_ip])
    error_message = "The firewall DNS proxy must forward to the resolver, or spokes cannot resolve privatelink names."
  }
}

run "platform_logs_reach_the_central_workspace" {
  command = apply

  assert {
    condition     = toset([for d in azurerm_monitor_diagnostic_setting.activity_log : d.target_resource_id]) == toset([for id in [var.management_subscription_id, var.connectivity_subscription_id, var.identity_subscription_id] : "/subscriptions/${id}"])
    error_message = "Every platform subscription sends its activity log to the central workspace."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.firewall.log_analytics_destination_type == "Dedicated"
    error_message = "Firewall logs go to resource-specific AZFW* tables."
  }

  assert {
    condition     = alltrue([for a in azurerm_monitor_metric_alert.firewall : one(a.action).action_group_id == module.management.action_group_id])
    error_message = "Firewall alerts must reach the platform action group."
  }
}

run "every_landing_zone_file_is_vended" {
  command = apply

  assert {
    condition = toset(keys(module.landing_zone)) == toset([
      for f in fileset("${path.module}/../../../landing-zones", "*.yaml") : trimsuffix(f, ".yaml")
    ])
    error_message = "Each landing-zones/<name>.yaml must produce one landing zone."
  }

  assert {
    condition     = module.landing_zone["payments"].route_table_id != null && module.landing_zone["aks-platform"].route_table_id == null
    error_message = "Only corp landing zones are forced through the firewall; the AKS platform is online."
  }

  assert {
    condition     = output.landing_zones["data-sandbox"].subscription_id == "77777777-7777-7777-7777-777777777777"
    error_message = "A landing zone with a billing scope gets a new subscription."
  }
}
