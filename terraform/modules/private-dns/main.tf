# Central DNS for the hub and every spoke:
#
#   spoke VM --> firewall DNS proxy --> resolver inbound endpoint --> Azure DNS
#                                                                     ├── privatelink zones (linked to the hub)
#                                                                     └── forwarding rules --> on-premises DNS
#
# Spokes never link privatelink zones themselves. One zone per service, in
# the connectivity subscription, means a private endpoint resolves the same
# way from every landing zone and from on-premises.

locals {
  inbound_subnet  = cidrsubnet(var.hub_address_space, 6, 10)
  outbound_subnet = cidrsubnet(var.hub_address_space, 6, 11)
  # Static, so the firewall DNS proxy and on-premises forwarders can be
  # configured before the resolver exists.
  inbound_ip = cidrhost(local.inbound_subnet, 4)
}

resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.private_dns_zones)

  name                = each.key
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = azurerm_private_dns_zone.this

  name                 = "link-hub"
  private_dns_zone_id  = each.value.id
  virtual_network_id   = var.hub_vnet_id
  registration_enabled = false
  tags                 = var.tags
}

# --- DNS Private Resolver -----------------------------------------------------

resource "azurerm_subnet" "resolver" {
  for_each = {
    inbound  = local.inbound_subnet
    outbound = local.outbound_subnet
  }

  name                            = "snet-dns-${each.key}"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = var.hub_vnet_name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false

  delegation {
    name = "dns-resolver"

    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_resolver" "this" {
  name                = "dnspr-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.hub_vnet_id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  name                    = "in"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = var.location
  tags                    = var.tags

  ip_configurations {
    subnet_id                    = azurerm_subnet.resolver["inbound"].id
    private_ip_allocation_method = "Static"
    private_ip_address           = local.inbound_ip
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  name                    = "out"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = var.location
  subnet_id               = azurerm_subnet.resolver["outbound"].id
  tags                    = var.tags
}

# Conditional forwarding for on-premises domains, e.g. corp.example.co.uk.
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  name                                       = "dnsfrs-${var.name}"
  location                                   = var.location
  resource_group_name                        = var.resource_group_name
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.this.id]
  tags                                       = var.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "this" {
  for_each = var.forwarding_rules

  name                      = replace(trimsuffix(each.key, "."), ".", "-")
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  domain_name               = endswith(each.key, ".") ? each.key : "${each.key}."
  enabled                   = true

  dynamic "target_dns_servers" {
    for_each = each.value

    content {
      ip_address = target_dns_servers.value
      port       = 53
    }
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub" {
  name                      = "link-hub"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  virtual_network_id        = var.hub_vnet_id
}
