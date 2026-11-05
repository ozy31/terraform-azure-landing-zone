locals {
  region_short = {
    uksouth = "uks"
    ukwest  = "ukw"
  }

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
