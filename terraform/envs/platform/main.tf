locals {
  region_short = {
    uksouth = "uks"
    ukwest  = "ukw"
  }

  tags = merge(var.tags, {
    managed-by = "terraform"
    repository = "terraform-azure-landing-zone"
  })

  # One file per landing zone. The file name is the landing zone name.
  landing_zones_dir = "${path.module}/../../../landing-zones"
  landing_zones = {
    for f in fileset(local.landing_zones_dir, "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.landing_zones_dir}/${f}"))
  }
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

module "hub" {
  source    = "../../modules/hub-network"
  providers = { azurerm = azurerm.connectivity }

  name                 = "alz-hub-${local.region_short[var.primary_location]}"
  location             = var.primary_location
  address_space        = var.hub_address_space
  spoke_address_ranges = [var.spoke_supernet]
  firewall_sku         = var.firewall_sku
  dns_servers          = [module.dns.inbound_endpoint_ip]
  tags                 = local.tags
}

module "dns" {
  source    = "../../modules/private-dns"
  providers = { azurerm = azurerm.connectivity }

  name                = "alz-hub-${local.region_short[var.primary_location]}"
  location            = var.primary_location
  resource_group_name = module.hub.resource_group_name
  hub_vnet_id         = module.hub.vnet_id
  hub_vnet_name       = module.hub.vnet_name
  hub_address_space   = var.hub_address_space
  forwarding_rules    = var.dns_forwarding_rules
  tags                = local.tags
}

module "management" {
  source = "../../modules/management"

  name         = "alz-mgmt-${local.region_short[var.primary_location]}"
  location     = var.primary_location
  alert_emails = var.platform_alert_emails
  tags         = local.tags
}

module "landing_zone" {
  source   = "../../modules/landing-zone"
  for_each = local.landing_zones

  name                = each.key
  archetype           = each.value.archetype
  management_group_id = module.management_groups.ids[each.value.archetype]
  location            = try(each.value.location, var.primary_location)
  address_space       = each.value.addressSpace
  owner_group_id      = each.value.ownerGroupId
  egress_fqdns        = try(each.value.egressFqdns, [])

  firewall_rule_priority     = try(each.value.firewallPriority, 1000)
  log_analytics_workspace_id = module.management.log_analytics_workspace_id

  subscription = {
    id               = try(each.value.subscriptionId, null)
    billing_scope_id = try(each.value.billingScopeId, null)
    workload         = try(each.value.workload, "Production")
  }

  budget = {
    amount         = each.value.budget.amount
    contact_emails = each.value.budget.contacts
  }

  hub = {
    vnet_id             = module.hub.vnet_id
    firewall_private_ip = module.hub.firewall_private_ip
    firewall_policy_id  = module.hub.firewall_policy_id
  }

  tags = merge(local.tags, {
    landing-zone = each.key
    cost-center  = each.value.costCenter
  })

  # Policy is in place before a subscription moves under it.
  depends_on = [module.policy]
}
