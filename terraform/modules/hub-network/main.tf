# The hub of a hub-and-spoke network: Azure Firewall for egress and
# east-west traffic between spokes, Bastion for admin access, and a gateway
# subnet kept free for VPN or ExpressRoute. Spokes peer to it and send
# 0.0.0.0/0 to the firewall (modules/landing-zone).

locals {
  # /22 hub: firewall /26, Bastion /26, gateway /27, DNS resolver 2 x /28.
  subnets = {
    AzureFirewallSubnet = cidrsubnet(var.address_space, 4, 0)
    AzureBastionSubnet  = cidrsubnet(var.address_space, 4, 1)
    GatewaySubnet       = cidrsubnet(var.address_space, 5, 4)
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = var.tags
}

# Subnet names are fixed by Azure for these services.
resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]
}

# --- Azure Firewall ---------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name}-afw"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = "afwp-${var.name}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  sku                      = var.firewall_sku
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  # The firewall answers DNS for the spokes, so FQDN network rules resolve
  # the same addresses the workloads do.
  dns {
    proxy_enabled = true
    servers       = var.dns_servers
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall_sku == "Premium" ? [1] : []

    content {
      mode = "Deny"
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "afw-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = var.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Rules every landing zone needs. Per-landing-zone rules are separate rule
# collection groups owned by the vending module, at priorities above 1000.
resource "azurerm_firewall_policy_rule_collection_group" "platform" {
  name               = "platform"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  network_rule_collection {
    name     = "platform-network"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "ntp"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_address_ranges
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  application_rule_collection {
    name     = "platform-application"
    priority = 300
    action   = "Allow"

    rule {
      name                  = "windows-update"
      source_addresses      = var.spoke_address_ranges
      destination_fqdn_tags = ["WindowsUpdate"]

      protocols {
        type = "Https"
        port = 443
      }

      protocols {
        type = "Http"
        port = 80
      }
    }

    rule {
      name              = "azure-monitor"
      source_addresses  = var.spoke_address_ranges
      destination_fqdns = ["*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com", "*.monitoring.azure.com", "*.handler.control.monitor.azure.com"]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# --- Bastion ----------------------------------------------------------------
# Admin access to VMs in any peered spoke without public IPs on them.
# Standard SKU for native client (az network bastion ssh) and tunnelling.

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.name}-bas"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  name                = "bas-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tunneling_enabled   = true
  copy_paste_enabled  = false
  zones               = var.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
