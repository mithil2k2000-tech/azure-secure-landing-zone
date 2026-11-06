variable "name_prefix" {
  type = string
}

variable "subscription_id" {
  description = "Subscription the initiative is assigned to (ID only, not the full resource ID)."
  type        = string
}

variable "location" {
  description = "Region for the assignment's managed identity."
  type        = string
}

variable "allowed_locations" {
  description = "Regions resources may be created in."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "enforcement_mode" {
  description = "true = Deny effects block non-compliant changes; false = evaluate and report only (DoNotEnforce)."
  type        = bool
  default     = true
}

variable "definitions_path" {
  description = "Folder holding the custom policy JSON files."
  type        = string
}

variable "assign_mcsb" {
  description = "Also assign the built-in Microsoft cloud security benchmark initiative in audit mode."
  type        = bool
  default     = true
}
