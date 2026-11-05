# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/mock"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/publicIPAddresses/mock"
    }
  }

  mock_resource "azurerm_firewall_policy" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/firewallPolicies/afwp-alz-hub-uks"
    }
  }

  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks"
    }
  }
}

# Firewall and Bastion check the subnet name inside the subnet ID.
override_resource {
  target = azurerm_subnet.this["AzureFirewallSubnet"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/AzureFirewallSubnet"
  }
}

override_resource {
  target = azurerm_subnet.this["AzureBastionSubnet"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-hub-uks/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-uks/subnets/AzureBastionSubnet"
  }
}

variables {
  name     = "alz-hub-uks"
  location = "uksouth"
}

run "address_plan" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["AzureFirewallSubnet"].address_prefixes[0] == "10.100.0.0/26"
    error_message = "AzureFirewallSubnet must be a /26."
  }

  assert {
    condition     = azurerm_subnet.this["AzureBastionSubnet"].address_prefixes[0] == "10.100.0.64/26"
    error_message = "AzureBastionSubnet must be at least a /26."
  }

  assert {
    condition     = azurerm_subnet.this["GatewaySubnet"].address_prefixes[0] == "10.100.0.128/27"
    error_message = "GatewaySubnet is reserved as a /27 for VPN or ExpressRoute."
  }
}

run "firewall_is_the_dns_proxy" {
  command = apply

  assert {
    condition     = azurerm_firewall_policy.this.dns[0].proxy_enabled
    error_message = "Spokes use the firewall as DNS server, so DNS proxy must be on."
  }

  assert {
    condition     = azurerm_firewall_policy.this.threat_intelligence_mode == "Deny"
    error_message = "Known-malicious destinations are blocked, not just logged."
  }
}

run "idps_only_on_premium" {
  command = plan

  variables {
    firewall_sku = "Premium"
  }

  assert {
    condition     = azurerm_firewall_policy.this.intrusion_detection[0].mode == "Deny"
    error_message = "Premium firewalls run IDPS in Deny mode."
  }
}

run "hub_must_be_a_22" {
  command = plan

  variables {
    address_space = "10.100.0.0/24"
  }

  expect_failures = [var.address_space]
}
