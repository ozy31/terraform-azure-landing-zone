terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.5"
    }
  }

  # Partial configuration: values come from backend.hcl. CI authenticates
  # with OIDC, never storage keys.
  backend "azurerm" {}
}

# Management groups, policy and logging live with the management subscription.
provider "azurerm" {
  subscription_id     = var.management_subscription_id
  storage_use_azuread = true

  features {}
}

provider "azurerm" {
  alias               = "connectivity"
  subscription_id     = var.connectivity_subscription_id
  storage_use_azuread = true

  features {}
}

# Landing zones: azapi addresses every subscription by resource ID.
provider "azapi" {
  subscription_id = var.management_subscription_id
}
