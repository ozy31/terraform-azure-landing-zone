variable "name" {
  description = "Name suffix, e.g. \"alz-hub-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Hub resource group."
  type        = string
}

variable "hub_vnet_id" {
  description = "Hub VNet the zones and the resolver are linked to."
  type        = string
}

variable "hub_vnet_name" {
  description = "Hub VNet name, for the resolver subnets."
  type        = string
}

variable "hub_address_space" {
  description = "Hub /22. The resolver uses the two /28s after GatewaySubnet."
  type        = string
}

variable "private_dns_zones" {
  description = "privatelink zones hosted centrally. Add a zone here before the first private endpoint for that service."
  type        = list(string)
  default = [
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.database.windows.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.servicebus.windows.net",
    "privatelink.uksouth.azmk8s.io",
    "privatelink.monitor.azure.com",
  ]
}

variable "forwarding_rules" {
  description = "Domain => DNS server IPs to forward to, for names Azure DNS cannot answer (on-premises)."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
