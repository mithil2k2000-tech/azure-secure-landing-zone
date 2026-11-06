output "hub_vnet_id" {
  value = module.hub.vnet_id
}

output "spoke_vnet_ids" {
  value = { for k, m in module.spoke : k => m.vnet_id }
}

output "policy_initiative_id" {
  value = module.policy.initiative_id
}

output "log_analytics_workspace_id" {
  value = module.hub.log_analytics_workspace_id
}
