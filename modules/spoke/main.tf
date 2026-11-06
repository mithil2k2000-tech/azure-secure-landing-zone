# Spoke: an isolated workload network peered to the hub, deny-by-default.

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.name_prefix}-${var.spoke_name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-${var.spoke_name}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each                          = var.subnets
  name                              = "snet-${each.key}"
  resource_group_name               = azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [cidrsubnet(var.address_space, each.value.newbits, each.value.netnum)]
  private_endpoint_network_policies = "Enabled"
  default_outbound_access_enabled   = false # no implicit internet egress (retired by Azure in 2025 for new VNets)
}

resource "azurerm_network_security_group" "this" {
  for_each            = var.subnets
  name                = "nsg-${var.name_prefix}-${var.spoke_name}-${each.key}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  # Only the ports a subnet declares are open, and only from inside the private address space.
  dynamic "security_rule" {
    for_each = length(each.value.allowed_inbound_ports) > 0 ? [1] : []
    content {
      name                       = "allow-internal-declared-ports"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = each.value.allowed_inbound_ports
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "VirtualNetwork"
    }
  }

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

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# Force all egress through the hub firewall when one exists.
resource "azurerm_route_table" "this" {
  count                         = var.firewall_private_ip == null ? 0 : 1
  name                          = "rt-${var.name_prefix}-${var.spoke_name}"
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = var.firewall_private_ip == null ? {} : var.subnets
  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}

# ---------- Peering (both directions) ----------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.spoke_name}-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.spoke_name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# ---------- VNet flow logs ----------
resource "azurerm_network_watcher_flow_log" "spoke" {
  name                 = "fl-${var.name_prefix}-${var.spoke_name}"
  network_watcher_name = var.network_watcher_name
  resource_group_name  = var.network_watcher_resource_group
  target_resource_id   = azurerm_virtual_network.spoke.id
  storage_account_id   = var.flowlog_storage_account_id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.log_analytics_workspace_guid
    workspace_region      = var.log_analytics_location
    workspace_resource_id = var.log_analytics_workspace_id
    interval_in_minutes   = 60
  }
}
