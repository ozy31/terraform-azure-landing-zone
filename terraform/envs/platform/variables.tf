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

variable "hub_address_space" {
  description = "Hub VNet range (/22)."
  type        = string
  default     = "10.100.0.0/22"
}

variable "spoke_supernet" {
  description = "Range connected spokes are allocated from (hack/check-landing-zones.py keeps a copy). Platform firewall rules use it as their source."
  type        = string
  default     = "10.0.0.0/10"
}

variable "firewall_sku" {
  description = "Azure Firewall tier: Standard, or Premium for TLS inspection and IDPS."
  type        = string
  default     = "Standard"
}

variable "dns_forwarding_rules" {
  description = "On-premises domains => DNS servers, forwarded by the DNS Private Resolver."
  type        = map(list(string))
  default     = {}
}

variable "platform_alert_emails" {
  description = "Platform team addresses for platform alerts."
  type        = list(string)
  default     = []
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
