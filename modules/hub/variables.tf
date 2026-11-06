variable "name_prefix" {
  description = "Short prefix used in every resource name, e.g. 'lz-dev-uks'."
  type        = string
}

variable "location" {
  description = "Azure region for the hub."
  type        = string
}

variable "address_space" {
  description = "Address space for the hub virtual network."
  type        = string
  default     = "10.0.0.0/22"
}

variable "enable_firewall" {
  description = "Deploy Azure Firewall (Basic SKU). Off by default because it is the main cost driver."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion (Developer SKU is free but limited; Basic costs ~£110/month)."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention for the central Log Analytics workspace."
  type        = number
  default     = 30
}

variable "tenant_id" {
  description = "Entra ID tenant used for the Key Vault."
  type        = string
}

variable "allowed_admin_cidrs" {
  description = "Public CIDRs allowed through the Key Vault firewall (e.g. your home IP). Empty means private only."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "create_network_watcher" {
  description = "Create a Network Watcher. Leave false to reuse the one Azure creates automatically in NetworkWatcherRG."
  type        = bool
  default     = false
}
