# Outputs for Microsoft Entra Domain Services deployment

# Domain Services Information
output "domain_service_id" {
  description = "The ID of the Entra Domain Services instance"
  value       = azapi_resource.domain_services.id
}

output "domain_service_name" {
  description = "The name of the Entra Domain Services instance"
  value       = azapi_resource.domain_services.name
}

output "domain_name" {
  description = "The domain name configured for the Domain Services"
  value       = jsondecode(azapi_resource.domain_services.output).properties.domainName
}

output "deployment_id" {
  description = "The deployment ID of the Domain Services"
  value       = jsondecode(azapi_resource.domain_services.output).properties.deploymentId
}

output "sync_owner" {
  description = "The sync owner of the Domain Services"
  value       = jsondecode(azapi_resource.domain_services.output).properties.syncOwner
}

# Network Information
output "resource_group_name" {
  description = "The name of the resource group containing all resources"
  value       = azurerm_resource_group.main.name
}

output "virtual_network_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "virtual_network_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "domain_services_subnet_id" {
  description = "The ID of the Domain Services subnet"
  value       = azurerm_subnet.domain_services.id
}

output "domain_services_subnet_name" {
  description = "The name of the Domain Services subnet"
  value       = azurerm_subnet.domain_services.name
}

output "domain_services_subnet_address_prefix" {
  description = "The address prefix of the Domain Services subnet"
  value       = azurerm_subnet.domain_services.address_prefixes[0]
}

# Replica Sets Information
output "replica_sets" {
  description = "Information about replica sets"
  value = length(var.replica_sets) > 0 ? {
    for idx, replica in var.replica_sets : idx => {
      location    = replica.location
      subnet_id   = azurerm_subnet.replica_sets[idx].id
      subnet_name = azurerm_subnet.replica_sets[idx].name
    }
  } : {}
}

# Security Information
output "network_security_group_id" {
  description = "The ID of the Network Security Group for Domain Services"
  value       = azurerm_network_security_group.domain_services.id
}

output "network_security_group_name" {
  description = "The name of the Network Security Group for Domain Services"
  value       = azurerm_network_security_group.domain_services.name
}

# Monitoring Information
output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace (if created)"
  value       = var.enable_diagnostic_settings && var.log_analytics_workspace_id == "" ? azurerm_log_analytics_workspace.main[0].id : var.log_analytics_workspace_id
}

output "key_vault_id" {
  description = "The ID of the Key Vault (if created for secure LDAP)"
  value       = var.enable_secure_ldap ? azurerm_key_vault.main[0].id : null
}

output "key_vault_uri" {
  description = "The URI of the Key Vault (if created for secure LDAP)"
  value       = var.enable_secure_ldap ? azurerm_key_vault.main[0].vault_uri : null
}

# Configuration Information
output "sku" {
  description = "The SKU of the Domain Services"
  value       = jsondecode(azapi_resource.domain_services.output).properties.sku
}

output "filtered_sync_enabled" {
  description = "Whether filtered sync is enabled"
  value       = jsondecode(azapi_resource.domain_services.output).properties.filteredSync == "Enabled"
}

output "secure_ldap_enabled" {
  description = "Whether secure LDAP is enabled"
  value       = var.enable_secure_ldap
}

# Connection Information
output "ldap_connection_info" {
  description = "LDAP connection information"
  value = {
    ldap_port         = "389"
    ldaps_port        = "636"
    domain_name       = jsondecode(azapi_resource.domain_services.output).properties.domainName
    subnet_cidr       = azurerm_subnet.domain_services.address_prefixes[0]
    dns_servers       = "Provided by Azure AD Domain Services"
  }
}

# Domain Administrator Group
output "domain_administrators_group" {
  description = "Information about the Domain Administrators group"
  value = {
    group_id      = data.azuread_group.dc_administrators.object_id
    display_name  = data.azuread_group.dc_administrators.display_name
    admin_users   = var.domain_admin_users
  }
}

# Tags
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = var.common_tags
}

# Backup Information
output "backup_storage_account" {
  description = "Information about the backup storage account (if enabled)"
  value = var.enable_backup && var.sku == "Enterprise" ? {
    id           = azurerm_storage_account.backup[0].id
    name         = azurerm_storage_account.backup[0].name
    primary_blob_endpoint = azurerm_storage_account.backup[0].primary_blob_endpoint
  } : null
}

# DNS Configuration Instructions
output "dns_configuration_instructions" {
  description = "Instructions for configuring DNS"
  value = {
    message = "Configure your DNS to use Azure AD Domain Services. Update your DNS servers to point to the Domain Controllers."
    next_steps = [
      "1. Note the IP addresses of the Domain Controllers from the Azure portal",
      "2. Update your virtual network DNS settings to use these IP addresses",
      "3. Restart VMs in the virtual network for DNS changes to take effect",
      "4. Test domain join and authentication functionality"
    ]
  }
}

# Post-Deployment Tasks
output "post_deployment_tasks" {
  description = "Important tasks to complete after deployment"
  value = [
    "1. Configure DNS settings in your virtual network to use Domain Services DNS",
    "2. Join VMs to the domain using the domain administrator accounts",
    "3. Configure Group Policy objects as needed",
    "4. Set up secure LDAP certificate if enabled",
    "5. Configure monitoring and alerting",
    "6. Review and adjust Network Security Group rules as needed",
    "7. Test authentication and authorization functionality",
    "8. Configure backup settings if using Enterprise SKU"
  ]
}