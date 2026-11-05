variable "name" {
  description = "Name suffix, e.g. \"alz-hub-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Hub VNet address space. Must not overlap any spoke or on-premises range."
  type        = string
  default     = "10.100.0.0/22"

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && tonumber(split("/", var.address_space)[1]) == 22
    error_message = "The hub address plan is laid out for a /22."
  }
}

variable "spoke_address_ranges" {
  description = "Address ranges of all spokes, the source of the platform firewall rules."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "firewall_sku" {
  description = "Standard, or Premium for TLS inspection and IDPS."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "firewall_sku must be Standard or Premium. Basic does not support DNS proxy or FQDN tags at scale."
  }
}

variable "dns_servers" {
  description = "Upstream DNS servers for the firewall DNS proxy. Empty uses Azure DNS."
  type        = list(string)
  default     = []
}

variable "zones" {
  description = "Availability zones for the firewall, Bastion and their public IPs."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
