terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
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
