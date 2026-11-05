variable "management_group_ids" {
  description = "Management group IDs from the management-groups module."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["root", "landing-zones", "corp", "sandbox", "decommissioned"] : contains(keys(var.management_group_ids), k)])
    error_message = "management_group_ids must contain root, landing-zones, corp, sandbox and decommissioned."
  }
}

variable "location" {
  description = "Region for the identities of modify policies."
  type        = string
}

variable "allowed_locations" {
  description = "Regions where resources and resource groups may be created."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "required_tags" {
  description = "Tags every resource group must have; resources inherit them when missing."
  type        = list(string)
  default     = ["cost-center"]

  validation {
    condition     = alltrue([for t in var.required_tags : length(t) <= 12])
    error_message = "Tag names are part of 24-character assignment names: keep them to 12 characters."
  }
}

variable "subnet_nsg_effect" {
  description = "Effect of the subnet NSG rule in the landing zone baseline. Audit until existing VNets are compliant, then Deny."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.subnet_nsg_effect)
    error_message = "subnet_nsg_effect must be Audit, Deny or Disabled."
  }
}

variable "sandbox_denied_resource_types" {
  description = "Resource types sandboxes may not create: anything that would connect them to the corporate network."
  type        = list(string)
  default = [
    "Microsoft.Network/expressRouteCircuits",
    "Microsoft.Network/expressRouteGateways",
    "Microsoft.Network/vpnGateways",
    "Microsoft.Network/virtualNetworkGateways",
    "Microsoft.Network/virtualWans",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
  ]
}

variable "do_not_enforce" {
  description = "Assignment names to run in DoNotEnforce mode: new guardrails go out audit-only first, then are enforced once the compliance view is clean."
  type        = set(string)
  default     = []
}
