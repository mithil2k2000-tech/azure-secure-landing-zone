# Hub: shared networking, logging and secrets for every spoke.

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.name_prefix}-hub"
  location = var.location
  tags     = var.tags
}

# ---------- Central logging ----------
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = 1 # hard cap to stop runaway ingestion costs
  tags                = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Storage for NSG flow logs. Locked down: no public blob access, TLS 1.2, no shared keys.
resource "azurerm_storage_account" "flowlogs" {
  #checkov:skip=CKV2_AZURE_1:Customer-managed keys are out of scope for a lab; Microsoft-managed keys are used.
  #checkov:skip=CKV_AZURE_33:Queue service is not used by this account.
  #checkov:skip=CKV2_AZURE_33:A private endpoint for the flow-log account is planned (see ADR-0004).
  #checkov:skip=CKV_AZURE_43:Name is computed from a validated lowercase prefix and truncated to 24 characters; Checkov cannot evaluate the expression.
  name                            = substr(replace("stfl${var.name_prefix}${random_string.suffix.result}", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.hub.name
  location                        = azurerm_resource_group.hub.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  https_traffic_only_enabled      = true
  local_user_enabled              = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00"
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  tags = var.tags
}

# ---------- Hub network ----------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = [var.address_space]
  tags                = var.tags
}

# Azure requires these exact subnet names for Firewall and Bastion.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 0)]
}

resource "azurerm_subnet" "firewall_mgmt" {
  #checkov:skip=CKV2_AZURE_31:Azure does not allow an NSG on AzureFirewallManagementSubnet.
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 1)]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 2)]
}

# Bastion needs Microsoft's documented rule set on its subnet:
# https://learn.microsoft.com/azure/bastion/bastion-nsg
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${var.name_prefix}-bastion"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  # Bastion's public endpoint must accept HTTPS from the internet (Microsoft-required rule).
  #trivy:ignore:AZU-0047
  security_rule {
    name                       = "allow-https-inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-gateway-manager"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-azure-load-balancer"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-bastion-host-comms"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "allow-ssh-rdp-to-vnet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "allow-azure-cloud"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
  security_rule {
    name                       = "allow-bastion-comms-out"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "allow-session-info"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_subnet" "shared" {
  name                              = "snet-shared-services"
  resource_group_name               = azurerm_resource_group.hub.name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [cidrsubnet(var.address_space, 4, 3)]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "shared" {
  name                = "nsg-${var.name_prefix}-shared"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  # Explicit deny-all inbound below Azure's default rules so intent is visible in code and audits.
  # This is a Deny rule; the "unrestricted ingress" check matches on source "*" regardless of access.
  #trivy:ignore:AZU-0047
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "shared" {
  subnet_id                 = azurerm_subnet.shared.id
  network_security_group_id = azurerm_network_security_group.shared.id
}

# ---------- Azure Firewall (optional, Basic SKU) ----------
resource "azurerm_public_ip" "firewall" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-${var.name_prefix}-afw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "firewall_mgmt" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-${var.name_prefix}-afw-mgmt"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afwp-${var.name_prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Basic"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  count              = var.enable_firewall ? 1 : 0
  name               = "rcg-baseline"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 100

  application_rule_collection {
    name     = "allow-os-updates"
    priority = 100
    action   = "Allow"

    rule {
      name = "windows-and-ubuntu-updates"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.0.0.0/8"]
      destination_fqdns = ["*.update.microsoft.com", "*.windowsupdate.com", "*.ubuntu.com", "packages.microsoft.com"]
    }
  }
}

resource "azurerm_firewall" "this" {
  #checkov:skip=CKV_AZURE_219:Threat intelligence 'Deny' mode requires Standard SKU; Basic SKU is used for cost (ADR-0003).
  #checkov:skip=CKV_AZURE_216:Basic SKU does not support threat-intel deny mode (ADR-0003).
  count               = var.enable_firewall ? 1 : 0
  name                = "afw-${var.name_prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = ["1", "2", "3"]
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  management_ip_configuration {
    name                 = "mgmt"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.firewall_mgmt[0].id
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count                          = var.enable_firewall ? 1 : 0
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.this[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------- Azure Bastion (optional) ----------
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.name_prefix}-bas"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.name_prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ---------- Key Vault for shared secrets ----------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV2_AZURE_32:Private endpoint is added when a workload needs it (ADR-0004); public access is firewall-restricted.
  #checkov:skip=CKV_AZURE_189:Public access is disabled unless allowed_admin_cidrs is set, and then limited to those IPs with default Deny.
  name                          = substr("kv-${replace(var.name_prefix, "-", "")}${random_string.suffix.result}", 0, 24)
  location                      = azurerm_resource_group.hub.location
  resource_group_name           = azurerm_resource_group.hub.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = length(var.allowed_admin_cidrs) > 0
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_admin_cidrs
  }
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------- Network Watcher + VNet flow logs ----------
# Azure allows one Network Watcher per region and usually creates it automatically
# (NetworkWatcher_<region> in NetworkWatcherRG). Reuse it unless told to create one.
resource "azurerm_network_watcher" "this" {
  count               = var.create_network_watcher ? 1 : 0
  name                = "nw-${var.name_prefix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

data "azurerm_network_watcher" "existing" {
  count               = var.create_network_watcher ? 0 : 1
  name                = "NetworkWatcher_${replace(lower(var.location), " ", "")}"
  resource_group_name = "NetworkWatcherRG"
}

locals {
  network_watcher_name = var.create_network_watcher ? azurerm_network_watcher.this[0].name : data.azurerm_network_watcher.existing[0].name
  network_watcher_rg   = var.create_network_watcher ? azurerm_resource_group.hub.name : "NetworkWatcherRG"
}

# VNet flow logs replace NSG flow logs, which Azure is retiring (ADR-0005).
resource "azurerm_network_watcher_flow_log" "hub" {
  name                 = "fl-${var.name_prefix}-hub"
  network_watcher_name = local.network_watcher_name
  resource_group_name  = local.network_watcher_rg
  target_resource_id   = azurerm_virtual_network.hub.id
  storage_account_id   = azurerm_storage_account.flowlogs.id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.this.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.this.location
    workspace_resource_id = azurerm_log_analytics_workspace.this.id
    interval_in_minutes   = 60
  }
}
