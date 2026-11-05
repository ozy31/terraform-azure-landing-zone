# Cloud Adoption Framework hierarchy under the tenant root group:
#
#   <prefix>
#   ├── platform        connectivity, management, identity
#   ├── landing-zones   corp (private, hub-connected), online (internet-facing)
#   ├── sandbox         experiments, no hub connectivity
#   └── decommissioned  subscriptions waiting to be cancelled
#
# Policy is assigned to these groups, never to single subscriptions, so a
# subscription gets its guardrails by where it is placed.

locals {
  mg_id_prefix = "/providers/Microsoft.Management/managementGroups"

  level1 = {
    platform       = "Platform"
    landing-zones  = "Landing zones"
    sandbox        = "Sandbox"
    decommissioned = "Decommissioned"
  }

  level2 = {
    connectivity = { parent = "platform", display_name = "Connectivity" }
    management   = { parent = "platform", display_name = "Management" }
    identity     = { parent = "platform", display_name = "Identity" }
    corp         = { parent = "landing-zones", display_name = "Corp" }
    online       = { parent = "landing-zones", display_name = "Online" }
  }
}

resource "azurerm_management_group" "root" {
  name                       = var.prefix
  display_name               = var.root_display_name
  parent_management_group_id = var.parent_management_group_id
}

resource "azurerm_management_group" "level1" {
  for_each = local.level1

  name                       = "${var.prefix}-${each.key}"
  display_name               = each.value
  parent_management_group_id = "${local.mg_id_prefix}/${azurerm_management_group.root.name}"
}

resource "azurerm_management_group" "level2" {
  for_each = local.level2

  name                       = "${var.prefix}-${each.key}"
  display_name               = each.value.display_name
  parent_management_group_id = "${local.mg_id_prefix}/${azurerm_management_group.level1[each.value.parent].name}"
}

# IDs are built from names: they are fixed by the name, and readable in a plan.
locals {
  ids = merge(
    { root = "${local.mg_id_prefix}/${azurerm_management_group.root.name}" },
    { for k, mg in azurerm_management_group.level1 : k => "${local.mg_id_prefix}/${mg.name}" },
    { for k, mg in azurerm_management_group.level2 : k => "${local.mg_id_prefix}/${mg.name}" },
  )
}

# Platform subscriptions are placed here. Landing zone subscriptions are
# placed by the vending module, next to the rest of their definition.
resource "azurerm_management_group_subscription_association" "this" {
  for_each = var.subscription_placement

  management_group_id = local.ids[each.value]
  subscription_id     = "/subscriptions/${each.key}"
}

