variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID. The tenant root group has the same ID."
  type        = string
}

variable "root_display_name" {
  description = "Display name of the top management group."
  type        = string
}

variable "management_subscription_id" {
  description = "Platform subscription for logging, policy identities and the Terraform state."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Platform subscription for the hub network."
  type        = string
}

variable "identity_subscription_id" {
  description = "Platform subscription for identity workloads (domain controllers, if any)."
  type        = string
}

variable "primary_location" {
  description = "Primary region."
  type        = string
  default     = "uksouth"
}

variable "policy_do_not_enforce" {
  description = "Policy assignments to run audit-only while they are rolled out."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
