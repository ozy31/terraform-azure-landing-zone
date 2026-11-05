# Subscription vending: everything a team gets with a new landing zone.
#
#   subscription (created from a billing scope, or an existing one)
#   ├── placed in its archetype's management group (corp, online, sandbox)
#   ├── activity log to the central workspace
#   ├── budget with actual and forecast alerts
#   ├── team group as Contributor
#   └── rg-<name>-network
#       ├── VNet (DNS = hub firewall), peered both ways with the hub
#       ├── NSG and route table for the team's subnets
#       │   corp: 0.0.0.0/0 -> hub firewall
#       └── corp: firewall rule collection group for the team's egress FQDNs
#
# Written with azapi: one provider reaches every subscription by resource ID,
# so a new landing zone does not need a new provider block.

locals {
  connected = var.archetype != "sandbox"
  corp      = var.archetype == "corp"

  subscription_id = var.subscription.id != null ? var.subscription.id : azapi_resource.alias[0].output.properties.subscriptionId
  sub_scope       = "/subscriptions/${local.subscription_id}"

  # Built-in role IDs are the same in every tenant.
  contributor_role_id = "b24988ac-6180-42a0-ab88-20f7382dd24c"
}

# --- Subscription -----------------------------------------------------------

resource "azapi_resource" "alias" {
  count = var.subscription.id == null ? 1 : 0

  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = "lz-${var.name}"
  parent_id = "/"

  body = {
    properties = {
      displayName  = "lz-${var.name}"
      workload     = var.subscription.workload
      billingScope = var.subscription.billing_scope_id
      additionalProperties = {
        managementGroupId = var.management_group_id
        tags              = var.tags
      }
    }
  }

  response_export_values = ["properties.subscriptionId"]

  # Cancelling a subscription is not something a terraform destroy should do.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azapi_resource" "management_group_association" {
  type      = "Microsoft.Management/managementGroups/subscriptions@2023-04-01"
  name      = local.subscription_id
  parent_id = var.management_group_id
  body      = {}
}

resource "azapi_resource" "activity_log" {
  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "activity-to-log-analytics"
  parent_id = local.sub_scope

  body = {
    properties = {
      workspaceId = var.log_analytics_workspace_id
      logs = [for c in ["Administrative", "Security", "Policy", "ServiceHealth", "Alert", "ResourceHealth"] : {
        category = c
        enabled  = true
      }]
    }
  }
}

resource "azapi_resource" "budget" {
  type      = "Microsoft.Consumption/budgets@2023-11-01"
  name      = "budget-${var.name}"
  parent_id = local.sub_scope

  body = {
    properties = {
      category   = "Cost"
      amount     = var.budget.amount
      timeGrain  = "Monthly"
      timePeriod = { startDate = "${var.budget.start_month}-01T00:00:00Z" }
      notifications = {
        actual-80 = {
          enabled       = true
          operator      = "GreaterThan"
          threshold     = 80
          thresholdType = "Actual"
          contactEmails = var.budget.contact_emails
        }
        forecast-100 = {
          enabled       = true
          operator      = "GreaterThan"
          threshold     = 100
          thresholdType = "Forecasted"
          contactEmails = var.budget.contact_emails
        }
      }
    }
  }
}

resource "azapi_resource" "owner_contributor" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.sub_scope}/${var.owner_group_id}/contributor")
  parent_id = local.sub_scope

  body = {
    properties = {
      roleDefinitionId = "${local.sub_scope}/providers/Microsoft.Authorization/roleDefinitions/${local.contributor_role_id}"
      principalId      = var.owner_group_id
      principalType    = "Group"
    }
  }
}

# --- Network ----------------------------------------------------------------

resource "azapi_resource" "network_rg" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = "rg-${var.name}-network"
  parent_id = local.sub_scope
  location  = var.location
  tags      = var.tags
  body      = {}
}

resource "azapi_resource" "nsg" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  name      = "nsg-${var.name}-default"
  parent_id = azapi_resource.network_rg.id
  location  = var.location
  tags      = var.tags
  body      = { properties = {} }

  # Teams add their own rules.
  lifecycle {
    ignore_changes = [body.properties.securityRules]
  }
}

resource "azapi_resource" "route_table" {
  count = local.corp ? 1 : 0

  type      = "Microsoft.Network/routeTables@2024-05-01"
  name      = "rt-${var.name}-default"
  parent_id = azapi_resource.network_rg.id
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      # Routes learned from a VPN or ExpressRoute gateway must not bypass
      # the firewall.
      disableBgpRoutePropagation = true
      routes = [{
        name = "default-via-hub-firewall"
        properties = {
          addressPrefix    = "0.0.0.0/0"
          nextHopType      = "VirtualAppliance"
          nextHopIpAddress = var.hub.firewall_private_ip
        }
      }]
    }
  }
}

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-${var.name}"
  parent_id = azapi_resource.network_rg.id
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      addressSpace = { addressPrefixes = [var.address_space] }
      # Connected spokes resolve through the firewall DNS proxy, which
      # forwards to the central resolver and privatelink zones.
      dhcpOptions = { dnsServers = local.connected ? [var.hub.firewall_private_ip] : [] }
    }
  }

  # Subnets belong to the team (with the NSG and route table above). Without
  # this, the next apply would delete them.
  lifecycle {
    ignore_changes = [body.properties.subnets]
  }
}

# Peering changes on the hub VNet are serialised: concurrent updates from
# several landing zones fail with "AnotherOperationInProgress".
resource "azapi_resource" "peering_to_hub" {
  count = local.connected ? 1 : 0

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = "to-hub"
  parent_id = azapi_resource.vnet.id
  locks     = [var.hub.vnet_id]

  body = {
    properties = {
      remoteVirtualNetwork      = { id = var.hub.vnet_id }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
    }
  }
}

resource "azapi_resource" "peering_from_hub" {
  count = local.connected ? 1 : 0

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  name      = "to-${var.name}"
  parent_id = var.hub.vnet_id
  locks     = [var.hub.vnet_id]

  body = {
    properties = {
      remoteVirtualNetwork      = { id = azapi_resource.vnet.id }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      useRemoteGateways         = false
    }
  }
}

# Corp egress is deny-by-default at the firewall; the team lists what it
# needs, and the list is reviewed with the rest of the landing zone.
resource "azapi_resource" "egress_rules" {
  count = local.corp && length(var.egress_fqdns) > 0 ? 1 : 0

  type      = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01"
  name      = "lz-${var.name}"
  parent_id = var.hub.firewall_policy_id
  locks     = [var.hub.firewall_policy_id]

  body = {
    properties = {
      priority = var.firewall_rule_priority
      ruleCollections = [{
        ruleCollectionType = "FirewallPolicyFilterRuleCollection"
        name               = "egress"
        priority           = 100
        action             = { type = "Allow" }
        rules = [{
          ruleType        = "ApplicationRule"
          name            = "allowed-fqdns"
          sourceAddresses = [var.address_space]
          targetFqdns     = var.egress_fqdns
          protocols       = [{ protocolType = "Https", port = 443 }]
        }]
      }]
    }
  }
}
