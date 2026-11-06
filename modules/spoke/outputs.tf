output "resource_group_name" {
  value = azurerm_resource_group.spoke.name
}

output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}
