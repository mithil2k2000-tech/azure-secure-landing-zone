variable "subscription_id" {
  description = "Target subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID."
  type        = string
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  description = "Owner tag value, e.g. your email or team name."
  type        = string
}

variable "cost_centre" {
  type    = string
  default = "portfolio"
}

variable "enable_firewall" {
  description = "Deploy Azure Firewall Basic (~£250/month). Leave false for a low-cost demo."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "allowed_admin_cidrs" {
  type    = list(string)
  default = []
}

variable "policy_enforce" {
  description = "Enforce Deny policies. Set false on first rollout to see impact before blocking."
  type        = bool
  default     = true
}
