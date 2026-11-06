# Policy as code: custom definitions live as JSON in /policies/definitions and are
# grouped into one initiative assigned at subscription scope.

locals {
  files = fileset(var.definitions_path, "*.json")
  definitions = {
    for f in local.files : trimsuffix(f, ".json") => jsondecode(file("${var.definitions_path}/${f}"))
  }
}

resource "azurerm_policy_definition" "custom" {
  for_each     = local.definitions
  name         = "lz-${each.key}"
  policy_type  = "Custom"
  mode         = each.value.mode
  display_name = each.value.displayName
  description  = each.value.description
  metadata     = jsonencode(each.value.metadata)
  parameters   = jsonencode(each.value.parameters)
  policy_rule  = jsonencode(each.value.policyRule)
}

resource "azurerm_policy_set_definition" "baseline" {
  name         = "lz-${var.name_prefix}-baseline"
  policy_type  = "Custom"
  display_name = "Landing zone security baseline (${var.name_prefix})"
  description  = "Location, tagging, network exposure, storage transport and Key Vault controls for the landing zone."
  metadata     = jsonencode({ category = "Security", version = "1.0.0" })

  parameters = jsonencode({
    allowedLocations = {
      type     = "Array"
      metadata = { displayName = "Allowed locations", strongType = "location" }
    }
  })

  dynamic "policy_definition_reference" {
    for_each = azurerm_policy_definition.custom
    content {
      policy_definition_id = policy_definition_reference.value.id
      reference_id         = policy_definition_reference.key
      parameter_values = policy_definition_reference.key == "allowed-locations" ? jsonencode({
        allowedLocations = { value = "[parameters('allowedLocations')]" }
      }) : null
    }
  }
}

resource "azurerm_subscription_policy_assignment" "baseline" {
  name                 = "lz-baseline"
  display_name         = "Landing zone security baseline"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  enforce              = var.enforcement_mode
  location             = var.location

  parameters = jsonencode({
    allowedLocations = { value = var.allowed_locations }
  })

  non_compliance_message {
    content = "Blocked by the landing zone security baseline. See docs/controls-mapping.md for the rule and how to comply."
  }

  identity {
    type = "SystemAssigned"
  }
}

# Microsoft cloud security benchmark (built-in, the default Defender for Cloud initiative), audit only.
resource "azurerm_subscription_policy_assignment" "mcsb" {
  count                = var.assign_mcsb ? 1 : 0
  name                 = "lz-mcsb-audit"
  display_name         = "Microsoft cloud security benchmark (audit)"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  enforce              = false
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}
