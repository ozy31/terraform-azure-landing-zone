# Policy is assigned to management groups, so a subscription's guardrails
# follow from where it is placed. Custom definitions are JSON files in
# definitions/ (the same shape as the portal export) and live at the root
# management group, so every assignment below it can use them.

locals {
  root_id = var.management_group_ids["root"]

  custom_definitions = {
    for f in fileset("${path.module}/definitions", "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/definitions/${f}"))
  }

  # Built-ins are looked up by display name, so a plan says what is assigned.
  # A wrong name fails the plan, not the apply.
  builtin = {
    allowed_locations    = "Allowed locations"
    allowed_rg_locations = "Allowed locations for resource groups"
    require_rg_tag       = "Require a tag on resource groups"
    inherit_rg_tag       = "Inherit a tag from the resource group if missing"
    not_allowed_types    = "Not allowed resource types"
    allowed_types        = "Allowed resource types"
    storage_https        = "Secure transfer to storage accounts should be enabled"
    kv_deletion          = "Key vaults should have deletion protection enabled"
    aks_local_auth       = "Azure Kubernetes Service Clusters should have local authentication methods disabled"
  }
}

data "azurerm_policy_definition" "builtin" {
  for_each = local.builtin

  display_name = each.value
}

resource "azurerm_policy_definition" "custom" {
  for_each = local.custom_definitions

  name                = each.value.name
  display_name        = each.value.displayName
  description         = each.value.description
  mode                = each.value.mode
  policy_type         = "Custom"
  management_group_id = local.root_id
  parameters          = jsonencode(each.value.parameters)
  policy_rule         = jsonencode(each.value.policyRule)
  metadata            = jsonencode({ category = "Landing zone", source = "terraform-azure-landing-zone" })
}

# Baseline for every landing zone, grouped so it is one assignment and one
# compliance score.
resource "azurerm_management_group_policy_set_definition" "landing_zone_baseline" {
  name                = "lz-baseline"
  display_name        = "Landing zone baseline"
  policy_type         = "Custom"
  management_group_id = local.root_id

  parameters = jsonencode({
    nsgEffect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_definition_reference {
    reference_id         = "subnet-nsg"
    policy_definition_id = azurerm_policy_definition.custom["deny-subnet-without-nsg"].id
    parameter_values     = jsonencode({ effect = { value = "[parameters('nsgEffect')]" } })
  }

  policy_definition_reference {
    reference_id         = "storage-https"
    policy_definition_id = data.azurerm_policy_definition.builtin["storage_https"].id
  }

  policy_definition_reference {
    reference_id         = "kv-deletion-protection"
    policy_definition_id = data.azurerm_policy_definition.builtin["kv_deletion"].id
  }

  policy_definition_reference {
    reference_id         = "aks-local-auth"
    policy_definition_id = data.azurerm_policy_definition.builtin["aks_local_auth"].id
  }
}

locals {
  # name: assignment names at management group scope are limited to 24 characters.
  assignments = merge(
    {
      allowed-locations = {
        mg         = "root"
        definition = data.azurerm_policy_definition.builtin["allowed_locations"].id
        parameters = { listOfAllowedLocations = var.allowed_locations }
        message    = "Resources must be created in ${join(", ", var.allowed_locations)}."
      }
      allowed-rg-locations = {
        mg         = "root"
        definition = data.azurerm_policy_definition.builtin["allowed_rg_locations"].id
        parameters = { listOfAllowedLocations = var.allowed_locations }
        message    = "Resource groups must be created in ${join(", ", var.allowed_locations)}."
      }
      lz-baseline = {
        mg         = "landing-zones"
        definition = azurerm_management_group_policy_set_definition.landing_zone_baseline.id
        parameters = { nsgEffect = var.subnet_nsg_effect }
        message    = "See the landing zone baseline initiative for the failing rule."
      }
      corp-deny-public-ip = {
        mg         = "corp"
        definition = azurerm_policy_definition.custom["deny-public-ip"].id
        parameters = {}
        message    = "Corp landing zones use the hub firewall for egress and private endpoints for ingress; public IPs are not allowed."
      }
      sandbox-limits = {
        mg         = "sandbox"
        definition = data.azurerm_policy_definition.builtin["not_allowed_types"].id
        parameters = { listOfResourceTypesNotAllowed = var.sandbox_denied_resource_types }
        message    = "Sandboxes cannot connect to the corporate network."
      }
      decom-lockdown = {
        mg         = "decommissioned"
        definition = data.azurerm_policy_definition.builtin["allowed_types"].id
        parameters = { listOfResourceTypesAllowed = ["Microsoft.Resources/subscriptions/resourceGroups"] }
        message    = "This subscription is being decommissioned; no new resources."
      }
    },
    {
      for t in var.required_tags : "require-tag-${t}" => {
        mg         = "root"
        definition = data.azurerm_policy_definition.builtin["require_rg_tag"].id
        parameters = { tagName = t }
        message    = "Resource groups need a ${t} tag."
      }
    },
  )
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = local.assignments

  name                 = each.key
  display_name         = "ALZ: ${each.key}"
  management_group_id  = var.management_group_ids[each.value.mg]
  policy_definition_id = each.value.definition
  enforce              = !contains(var.do_not_enforce, each.key)
  parameters           = length(each.value.parameters) > 0 ? jsonencode({ for k, v in each.value.parameters : k => { value = v } }) : null

  non_compliance_message {
    content = each.value.message
  }
}

# Modify policies need an identity with rights to make the change.
resource "azurerm_management_group_policy_assignment" "inherit_tag" {
  for_each = toset(var.required_tags)

  name                 = "inherit-tag-${each.key}"
  display_name         = "ALZ: inherit ${each.key} from the resource group"
  management_group_id  = local.root_id
  policy_definition_id = data.azurerm_policy_definition.builtin["inherit_rg_tag"].id
  enforce              = !contains(var.do_not_enforce, "inherit-tag-${each.key}")
  location             = var.location
  parameters           = jsonencode({ tagName = { value = each.key } })

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "inherit_tag" {
  for_each = azurerm_management_group_policy_assignment.inherit_tag

  scope                = local.root_id
  role_definition_name = "Tag Contributor"
  principal_id         = each.value.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
