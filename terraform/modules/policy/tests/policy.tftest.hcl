# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
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

variables {
  location = "uksouth"
  management_group_ids = {
    root           = "/providers/Microsoft.Management/managementGroups/alz"
    landing-zones  = "/providers/Microsoft.Management/managementGroups/alz-landing-zones"
    corp           = "/providers/Microsoft.Management/managementGroups/alz-corp"
    online         = "/providers/Microsoft.Management/managementGroups/alz-online"
    sandbox        = "/providers/Microsoft.Management/managementGroups/alz-sandbox"
    decommissioned = "/providers/Microsoft.Management/managementGroups/alz-decommissioned"
  }
}

run "assignments_land_on_the_right_groups" {
  command = apply

  assert {
    condition     = azurerm_management_group_policy_assignment.this["corp-deny-public-ip"].management_group_id == var.management_group_ids["corp"]
    error_message = "Public IPs are denied in corp only; online landing zones need them."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.this["lz-baseline"].management_group_id == var.management_group_ids["landing-zones"]
    error_message = "The baseline covers corp and online through their parent."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.this["allowed-locations"].management_group_id == var.management_group_ids["root"]
    error_message = "Region limits apply to the whole hierarchy."
  }
}

run "assignment_names_fit_management_group_scope" {
  command = plan

  assert {
    condition     = alltrue([for k in keys(output.assignment_ids) : length(k) <= 24])
    error_message = "Assignment names at management group scope are limited to 24 characters."
  }
}

run "custom_definitions_are_loaded_from_json" {
  command = apply

  assert {
    condition     = toset(keys(azurerm_policy_definition.custom)) == toset(["deny-public-ip", "deny-subnet-without-nsg"])
    error_message = "Every file in definitions/ becomes a custom definition."
  }

  assert {
    condition     = jsondecode(azurerm_policy_definition.custom["deny-public-ip"].policy_rule).if.equals == "Microsoft.Network/publicIPAddresses"
    error_message = "deny-public-ip must target public IP addresses."
  }
}

run "staged_rollout" {
  command = apply

  variables {
    do_not_enforce = ["lz-baseline"]
  }

  assert {
    condition     = !azurerm_management_group_policy_assignment.this["lz-baseline"].enforce && azurerm_management_group_policy_assignment.this["allowed-locations"].enforce
    error_message = "do_not_enforce must switch only the named assignments to DoNotEnforce."
  }
}

run "inherit_tag_has_least_privilege" {
  command = apply

  assert {
    condition     = alltrue([for r in azurerm_role_assignment.inherit_tag : r.role_definition_name == "Tag Contributor"])
    error_message = "Modify policies need Tag Contributor and nothing broader."
  }
}

run "missing_management_group_is_rejected" {
  command = plan

  variables {
    management_group_ids = { root = "/providers/Microsoft.Management/managementGroups/alz" }
  }

  expect_failures = [var.management_group_ids]
}
