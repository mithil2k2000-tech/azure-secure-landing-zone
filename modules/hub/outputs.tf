output "resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Next hop for spoke route tables, or null when the firewall is disabled."
  value       = var.enable_firewall ? azurerm_firewall.this[0].ip_configuration[0].private_ip_address : null
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_guid" {
  value = azurerm_log_analytics_workspace.this.workspace_id
}

output "log_analytics_location" {
  value = azurerm_log_analytics_workspace.this.location
}

output "network_watcher_name" {
  value = local.network_watcher_name
}

output "network_watcher_resource_group" {
  value = local.network_watcher_rg
}

output "flowlog_storage_account_id" {
  value = azurerm_storage_account.flowlogs.id
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}
