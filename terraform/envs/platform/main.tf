locals {
  tags = merge(var.tags, {
    managed-by = "terraform"
    repository = "terraform-azure-landing-zone"
  })
}

module "management_groups" {
  source = "../../modules/management-groups"

  root_display_name          = var.root_display_name
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.entra_tenant_id}"

  subscription_placement = {
    (var.management_subscription_id)   = "management"
    (var.connectivity_subscription_id) = "connectivity"
    (var.identity_subscription_id)     = "identity"
  }
}

module "policy" {
  source = "../../modules/policy"

  management_group_ids = module.management_groups.ids
  location             = var.primary_location
  required_tags        = ["cost-center"]
  do_not_enforce       = var.policy_do_not_enforce
}
