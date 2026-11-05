# Runs without Azure credentials: the provider is mocked.
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock"
      output = { properties = { subscriptionId = "55555555-5555-5555-5555-555555555555" } }
    }
  }
}

variables {
  name                = "payments"
  archetype           = "corp"
  subscription        = { id = "44444444-4444-4444-4444-444444444444" }
  management_group_id = "/providers/Microsoft.Management/managementGroups/alz-corp"
  location            = "uksouth"
  address_space       = "10.1.0.0/22"
  owner_group_id      = "2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10"
  egress_fqdns        = ["api.stripe.com", "*.adyen.com"]
  budget = {
    amount         = 2000
    contact_emails = ["payments-team@example.co.uk"]
  }
  log_analytics_workspace_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-alz-mgmt-uks/providers/Microsoft.OperationalInsights/workspaces/log-alz-mgmt-uks"
  hub = {
    vnet_id             = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks"
    firewall_private_ip = "10.100.0.4"
    firewall_policy_id  = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/firewallPolicies/afwp-alz-hub-uks"
  }
}

run "corp_egress_goes_through_the_firewall" {
  command = apply

  assert {
    condition     = azapi_resource.route_table[0].body.properties.routes[0].properties.nextHopIpAddress == "10.100.0.4"
    error_message = "Corp spokes send 0.0.0.0/0 to the hub firewall."
  }

  assert {
    condition     = azapi_resource.route_table[0].body.properties.disableBgpRoutePropagation
    error_message = "Gateway routes must not bypass the firewall."
  }

  assert {
    condition     = tolist(azapi_resource.vnet.body.properties.dhcpOptions.dnsServers) == tolist(["10.100.0.4"])
    error_message = "Spokes resolve through the firewall DNS proxy."
  }

  assert {
    condition     = tolist(azapi_resource.egress_rules[0].body.properties.ruleCollections[0].rules[0].targetFqdns) == tolist(["api.stripe.com", "*.adyen.com"])
    error_message = "The team's egress FQDNs become a firewall rule collection group."
  }
}

run "peering_is_symmetric_and_serialised" {
  command = apply

  assert {
    condition     = azapi_resource.peering_to_hub[0].body.properties.remoteVirtualNetwork.id == var.hub.vnet_id && azapi_resource.peering_from_hub[0].parent_id == var.hub.vnet_id
    error_message = "Both sides of the hub peering are created."
  }

  assert {
    condition     = tolist(azapi_resource.peering_from_hub[0].locks) == tolist([var.hub.vnet_id]) && tolist(azapi_resource.peering_to_hub[0].locks) == tolist([var.hub.vnet_id])
    error_message = "Hub peering changes must hold a lock on the hub VNet."
  }
}

run "subscription_guardrails" {
  command = apply

  assert {
    condition     = azapi_resource.management_group_association.parent_id == var.management_group_id && azapi_resource.management_group_association.name == "44444444-4444-4444-4444-444444444444"
    error_message = "The subscription is placed in its archetype's management group."
  }

  assert {
    condition     = endswith(azapi_resource.owner_contributor.body.properties.roleDefinitionId, "/b24988ac-6180-42a0-ab88-20f7382dd24c")
    error_message = "The owning team gets Contributor, not Owner."
  }

  assert {
    condition     = azapi_resource.budget.body.properties.notifications["forecast-100"].thresholdType == "Forecasted"
    error_message = "The budget warns on forecast, before the money is spent."
  }
}

run "online_has_no_forced_tunnel" {
  command = apply

  variables {
    archetype           = "online"
    management_group_id = "/providers/Microsoft.Management/managementGroups/alz-online"
  }

  assert {
    condition     = length(azapi_resource.route_table) == 0 && length(azapi_resource.egress_rules) == 0
    error_message = "Online landing zones have their own egress (a public load balancer and NAT gateway would break with a forced tunnel)."
  }

  assert {
    condition     = length(azapi_resource.peering_to_hub) == 1
    error_message = "Online landing zones are still peered for private access to shared services."
  }
}

run "sandbox_is_isolated" {
  command = apply

  variables {
    archetype           = "sandbox"
    management_group_id = "/providers/Microsoft.Management/managementGroups/alz-sandbox"
  }

  assert {
    condition     = length(azapi_resource.peering_to_hub) == 0 && length(azapi_resource.peering_from_hub) == 0
    error_message = "Sandboxes are not peered to the hub."
  }

  assert {
    condition     = length(azapi_resource.vnet.body.properties.dhcpOptions.dnsServers) == 0
    error_message = "Sandboxes use Azure DNS, not the hub."
  }
}

run "vended_subscription" {
  command = apply

  variables {
    subscription = {
      billing_scope_id = "/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/7654321"
    }
  }

  assert {
    condition     = output.subscription_id == "55555555-5555-5555-5555-555555555555"
    error_message = "A vended subscription's ID comes from the alias."
  }

  assert {
    condition     = azapi_resource.alias[0].body.properties.additionalProperties.managementGroupId == var.management_group_id
    error_message = "A new subscription is created directly in its management group."
  }
}

run "exactly_one_subscription_source" {
  command = plan

  variables {
    subscription = {
      id               = "44444444-4444-4444-4444-444444444444"
      billing_scope_id = "/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/7654321"
    }
  }

  expect_failures = [var.subscription]
}
