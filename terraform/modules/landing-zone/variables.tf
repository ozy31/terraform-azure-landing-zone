variable "name" {
  description = "Landing zone name, e.g. \"payments\". Used in every resource name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", var.name))
    error_message = "name must be 3-24 lowercase letters, digits or hyphens."
  }
}

variable "archetype" {
  description = "corp: private, egress through the hub firewall. online: internet-facing, peered but with its own egress. sandbox: not connected. decommissioned: disconnected, nothing new allowed."
  type        = string

  validation {
    condition     = contains(["corp", "online", "sandbox", "decommissioned"], var.archetype)
    error_message = "archetype must be corp, online, sandbox or decommissioned."
  }
}

variable "subscription" {
  description = "Either id (an existing subscription) or billing_scope_id (create one through a subscription alias)."
  type = object({
    id               = optional(string)
    billing_scope_id = optional(string)
    workload         = optional(string, "Production")
  })

  validation {
    condition     = (var.subscription.id == null) != (var.subscription.billing_scope_id == null)
    error_message = "Set exactly one of subscription.id and subscription.billing_scope_id."
  }

  validation {
    condition     = contains(["Production", "DevTest"], var.subscription.workload)
    error_message = "subscription.workload must be Production or DevTest."
  }
}

variable "management_group_id" {
  description = "Management group of the archetype."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Spoke VNet range, allocated from the spoke supernet."
  type        = string

  validation {
    condition     = can(cidrhost(var.address_space, 0))
    error_message = "address_space must be a CIDR."
  }
}

variable "hub" {
  description = "Hub outputs: VNet ID, firewall private IP and firewall policy ID."
  type = object({
    vnet_id             = string
    firewall_private_ip = string
    firewall_policy_id  = string
  })
}

variable "owner_group_id" {
  description = "Entra group of the owning team. Gets Contributor on the subscription."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.owner_group_id))
    error_message = "owner_group_id must be an Entra group object ID."
  }
}

variable "budget" {
  description = "Monthly budget in the billing currency. Alerts at 80% actual and 100% forecast."
  type = object({
    amount         = number
    contact_emails = list(string)
    start_month    = optional(string, "2026-11")
  })

  validation {
    condition     = var.budget.amount > 0 && length(var.budget.contact_emails) > 0
    error_message = "A budget needs a positive amount and at least one contact."
  }

  validation {
    condition     = can(regex("^20[0-9]{2}-(0[1-9]|1[0-2])$", var.budget.start_month))
    error_message = "budget.start_month must be YYYY-MM."
  }
}

variable "egress_fqdns" {
  description = "Corp only: FQDNs the landing zone may reach over HTTPS through the hub firewall."
  type        = list(string)
  default     = []
}

variable "firewall_rule_priority" {
  description = "Priority of this landing zone's rule collection group. Unique per landing zone, above the platform group (200)."
  type        = number
  default     = 1000

  validation {
    condition     = var.firewall_rule_priority > 200 && var.firewall_rule_priority <= 65000
    error_message = "firewall_rule_priority must be between 201 and 65000."
  }
}

variable "log_analytics_workspace_id" {
  description = "Central workspace for the subscription's activity log."
  type        = string
}

variable "tags" {
  description = "Tags for the subscription and its network resources."
  type        = map(string)
  default     = {}
}
