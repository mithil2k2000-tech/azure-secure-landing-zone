locals {
  name_prefix = "lz-${var.environment}-uks"
  tags = {
    owner         = var.owner
    environment   = var.environment
    "cost-centre" = var.cost_centre
    managed-by    = "terraform"
    repo          = "azure-secure-landing-zone"
  }
}

# Guardrails first, so every resource below is created under them.
module "policy" {
  source           = "../../modules/policy"
  name_prefix      = local.name_prefix
  subscription_id  = var.subscription_id
  location         = var.location
  enforcement_mode = var.policy_enforce
  definitions_path = "${path.root}/../../policies/definitions"
}

module "hub" {
  source              = "../../modules/hub"
  name_prefix         = local.name_prefix
  location            = var.location
  address_space       = "10.0.0.0/22"
  tenant_id           = var.tenant_id
  enable_firewall     = var.enable_firewall
  enable_bastion      = var.enable_bastion
  allowed_admin_cidrs = var.allowed_admin_cidrs
  tags                = local.tags

  depends_on = [module.policy]
}

locals {
  spokes = {
    app = {
      address_space = "10.1.0.0/22"
      subnets = {
        web = { newbits = 2, netnum = 0, allowed_inbound_ports = ["443"] }
        api = { newbits = 2, netnum = 1, allowed_inbound_ports = ["8443"] }
      }
    }
    data = {
      address_space = "10.2.0.0/22"
      subnets = {
        db                = { newbits = 2, netnum = 0, allowed_inbound_ports = ["5432"] }
        private-endpoints = { newbits = 2, netnum = 1, allowed_inbound_ports = ["443"] }
      }
    }
  }
}

module "spoke" {
  for_each                       = local.spokes
  source                         = "../../modules/spoke"
  name_prefix                    = local.name_prefix
  spoke_name                     = each.key
  location                       = var.location
  address_space                  = each.value.address_space
  subnets                        = each.value.subnets
  hub_vnet_id                    = module.hub.vnet_id
  hub_vnet_name                  = module.hub.vnet_name
  hub_resource_group_name        = module.hub.resource_group_name
  firewall_private_ip            = module.hub.firewall_private_ip
  network_watcher_name           = module.hub.network_watcher_name
  network_watcher_resource_group = module.hub.network_watcher_resource_group
  flowlog_storage_account_id     = module.hub.flowlog_storage_account_id
  log_analytics_workspace_id     = module.hub.log_analytics_workspace_id
  log_analytics_workspace_guid   = module.hub.log_analytics_workspace_guid
  log_analytics_location         = module.hub.log_analytics_location
  tags                           = local.tags
}

# Subscription activity log to the central workspace (who changed what).
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = module.hub.log_analytics_workspace_id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Alert"
  }
}

# Budget alert so a forgotten demo never runs up a bill.
resource "azurerm_consumption_budget_subscription" "this" {
  name            = "budget-${local.name_prefix}"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = 20
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-11-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.owner]
  }

  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Forecasted"
    operator       = "GreaterThan"
    contact_emails = [var.owner]
  }
}
