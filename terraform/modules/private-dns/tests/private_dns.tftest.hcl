# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/privateDnsZones/mock"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/mock"
    }
  }

  mock_resource "azurerm_private_dns_resolver" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsResolvers/dnspr-alz-hub-uks"
    }
  }

  mock_resource "azurerm_private_dns_resolver_outbound_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsResolvers/dnspr-alz-hub-uks/outboundEndpoints/out"
    }
  }

  mock_resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-alz-hub-uks"
    }
  }
}

variables {
  name                = "alz-hub-uks"
  location            = "uksouth"
  resource_group_name = "rg-alz-hub-uks"
  hub_vnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks"
  hub_vnet_name       = "vnet-alz-hub-uks"
  hub_address_space   = "10.100.0.0/22"
  forwarding_rules = {
    "corp.example.co.uk" = ["192.168.10.10", "192.168.10.11"]
  }
}

run "resolver_fits_after_the_gateway_subnet" {
  command = apply

  assert {
    condition     = azurerm_subnet.resolver["inbound"].address_prefixes[0] == "10.100.0.160/28" && azurerm_subnet.resolver["outbound"].address_prefixes[0] == "10.100.0.176/28"
    error_message = "Resolver subnets must not overlap the firewall, Bastion or gateway subnets."
  }

  assert {
    condition     = output.inbound_endpoint_ip == "10.100.0.164"
    error_message = "The inbound endpoint has a fixed address that the firewall and on-premises use."
  }
}

run "zones_are_linked_to_the_hub_only" {
  command = apply

  assert {
    condition     = alltrue([for l in azurerm_private_dns_zone_virtual_network_link.hub : l.virtual_network_id == var.hub_vnet_id && !l.registration_enabled])
    error_message = "privatelink zones are linked to the hub, without auto-registration."
  }

  assert {
    condition     = length(output.private_dns_zone_ids) == length(var.private_dns_zones)
    error_message = "Every listed zone is created."
  }
}

run "forwarding_rules_are_fqdns" {
  command = apply

  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.this["corp.example.co.uk"].domain_name == "corp.example.co.uk."
    error_message = "Forwarding rule domains must end with a dot."
  }

  assert {
    condition     = length(azurerm_private_dns_resolver_forwarding_rule.this["corp.example.co.uk"].target_dns_servers) == 2
    error_message = "Both on-premises DNS servers are targets."
  }
}
