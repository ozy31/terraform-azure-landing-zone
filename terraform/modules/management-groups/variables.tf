variable "prefix" {
  description = "Management group ID prefix. IDs are tenant-wide and cannot be renamed later."
  type        = string
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,9}$", var.prefix))
    error_message = "prefix must be 2-10 lowercase letters, digits or hyphens."
  }
}

variable "root_display_name" {
  description = "Display name of the top management group."
  type        = string
}

variable "parent_management_group_id" {
  description = "Parent of the hierarchy, normally the tenant root group: /providers/Microsoft.Management/managementGroups/<tenant-id>."
  type        = string
}

variable "subscription_placement" {
  description = "Platform subscription ID => management group key (connectivity, management, identity, ...)."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([for mg in values(var.subscription_placement) : contains(
      ["root", "platform", "landing-zones", "sandbox", "decommissioned", "connectivity", "management", "identity", "corp", "online"], mg
    )])
    error_message = "Each subscription must be placed in a management group defined by this module."
  }

  validation {
    condition     = alltrue([for id in keys(var.subscription_placement) : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "Keys must be subscription GUIDs, without /subscriptions/."
  }
}
