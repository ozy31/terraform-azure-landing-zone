variable "name" {
  description = "Name suffix, e.g. \"alz-mgmt-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "retention_in_days" {
  description = "Interactive retention. Activity logs are kept 90 days in Azure anyway; 90 here keeps them queryable alongside firewall logs."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB, -1 for none. A cap protects the bill from a noisy source but drops data once reached."
  type        = number
  default     = -1
}

variable "alert_emails" {
  description = "Platform team addresses for platform alerts."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
