output "initiative_id" {
  value = azurerm_policy_set_definition.baseline.id
}

output "custom_definition_ids" {
  value = { for k, d in azurerm_policy_definition.custom : k => d.id }
}
