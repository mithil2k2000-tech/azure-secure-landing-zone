variable "name_prefix" {
  description = "Short prefix used in every resource name."
  type        = string
}

variable "spoke_name" {
  description = "Workload name for this spoke, e.g. 'app' or 'data'."
  type        = string
}

variable "location" {
  description = "Azure region for the spoke."
  type        = string
}

variable "address_space" {
  description = "Address space for the spoke virtual network. Must not overlap the hub or other spokes."
  type        = string
}

variable "subnets" {
  description = "Subnets to create: name => { newbits, netnum, allowed_inbound_ports } carved from the spoke address space."
  type = map(object({
    newbits               = number
    netnum                = number
    allowed_inbound_ports = list(string)
  }))
}

variable "hub_vnet_id" {
  description = "ID of the hub virtual network to peer with."
  type        = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "firewall_private_ip" {
  description = "Hub firewall private IP. When set, all spoke egress is forced through the firewall."
  type        = string
  default     = null
}

variable "network_watcher_name" {
  type = string
}

variable "network_watcher_resource_group" {
  type = string
}

variable "flowlog_storage_account_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "log_analytics_workspace_guid" {
  type = string
}

variable "log_analytics_location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
