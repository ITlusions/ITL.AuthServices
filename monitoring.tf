# Security and Monitoring configuration for Microsoft Entra Domain Services

# Log Analytics Workspace for diagnostic settings (if not provided)
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_diagnostic_settings && var.log_analytics_workspace_id == "" ? 1 : 0
  name                = "law-entraid-domain-services-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Monitoring"
  })
}

# Diagnostic settings for Domain Services
resource "azurerm_monitor_diagnostic_setting" "domain_services" {
  count              = var.enable_diagnostic_settings ? 1 : 0
  name               = "diag-entraid-domain-services"
  target_resource_id = azapi_resource.domain_services.id

  log_analytics_workspace_id = var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.main[0].id

  # Enable all specified log categories
  dynamic "enabled_log" {
    for_each = var.diagnostic_log_categories
    content {
      category = enabled_log.value
    }
  }

  # Enable metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Network Security Group for replica sets
resource "azurerm_network_security_group" "replica_sets" {
  count               = length(var.replica_sets)
  name                = "nsg-domain-services-replica-${count.index + 1}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow inbound LDAP
  security_rule {
    name                       = "AllowLDAP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = var.ldap_source_address_prefix
    destination_address_prefix = "*"
  }

  # Allow inbound LDAPS
  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = var.ldap_source_address_prefix
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Purpose = "Replica Set Security"
  })
}

# Associate NSGs with replica set subnets
resource "azurerm_subnet_network_security_group_association" "replica_sets" {
  count                     = length(var.replica_sets)
  subnet_id                 = azurerm_subnet.replica_sets[count.index].id
  network_security_group_id = azurerm_network_security_group.replica_sets[count.index].id
}

# Key Vault for storing sensitive data (certificates, passwords)
resource "azurerm_key_vault" "main" {
  count                       = var.enable_secure_ldap ? 1 : 0
  name                        = "kv-entraid-ds-${random_string.suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  # Access policy for current user/service principal
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
    ]
  }

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Secrets"
  })
}

# Store secure LDAP certificate password in Key Vault
resource "azurerm_key_vault_secret" "secure_ldap_password" {
  count        = var.enable_secure_ldap && var.secure_ldap_certificate_password != "" ? 1 : 0
  name         = "secure-ldap-certificate-password"
  value        = var.secure_ldap_certificate_password
  key_vault_id = azurerm_key_vault.main[0].id

  tags = merge(var.common_tags, {
    Purpose = "Secure LDAP Certificate"
  })
}

# Action Group for monitoring alerts
resource "azurerm_monitor_action_group" "domain_services" {
  count               = var.enable_diagnostic_settings ? 1 : 0
  name                = "ag-entraid-domain-services"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "EntraIDDS"

  dynamic "email_receiver" {
    for_each = var.notification_settings.additional_recipients
    content {
      name          = "Email-${replace(email_receiver.value, "@", "-at-")}"
      email_address = email_receiver.value
    }
  }

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Alerts"
  })
}

# Monitoring alert for Domain Services health
resource "azurerm_monitor_metric_alert" "domain_services_health" {
  count               = var.enable_diagnostic_settings ? 1 : 0
  name                = "alert-entraid-domain-services-health"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azapi_resource.domain_services.id]
  description         = "Alert when Domain Services health is degraded"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.AAD/DomainServices"
    metric_name      = "DomainServicesHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.domain_services[0].id
  }

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Health Monitoring"
  })
}

# Storage account for backup (Enterprise SKU only)
resource "azurerm_storage_account" "backup" {
  count                    = var.enable_backup && var.sku == "Enterprise" ? 1 : 0
  name                     = "stentraid${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Enable advanced security features
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Network access control
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.domain_services.id]
    bypass                     = ["AzureServices"]
  }

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Backup"
  })
}