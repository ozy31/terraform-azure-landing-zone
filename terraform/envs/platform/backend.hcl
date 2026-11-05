# Placeholder values for the state storage account in the management subscription.
resource_group_name  = "rg-alz-tfstate"
storage_account_name = "stalztfstate0001"
container_name       = "tfstate"
key                  = "platform.tfstate"
use_azuread_auth     = true
