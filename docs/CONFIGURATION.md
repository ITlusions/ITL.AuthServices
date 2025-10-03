# Configuration Guide

## Overview

This guide provides detailed information about configuring the Microsoft Entra Domain Services Terraform template.

## Configuration Files

### terraform.tfvars
Primary configuration file containing all deployment parameters.

```hcl
# Copy from terraform.tfvars.example and customize
cp terraform.tfvars.example terraform.tfvars
```

## Required Variables

### Basic Configuration

```hcl
# Resource Group Configuration
resource_group_name = "rg-entradomain-prod"
location           = "West Europe"

# Domain Configuration
domain_name         = "contoso.local"
domain_display_name = "Contoso Domain Services"

# Network Configuration
virtual_network_name = "vnet-entradomain"
address_space       = ["10.0.0.0/16"]
subnet_name         = "snet-domain-services"
subnet_address_prefix = "10.0.1.0/24"

# Tags
tags = {
  Environment = "Production"
  Project     = "Authentication"
  Owner       = "IT Team"
  CostCenter  = "IT-001"
}
```

### Advanced Configuration

```hcl
# SKU Configuration
sku = "Standard"  # Options: Standard, Enterprise, Premium

# Security Configuration
filtered_sync_enabled = false
secure_ldap_enabled   = true

# Notifications
notification_settings = {
  notify_dc_admins         = true
  notify_global_admins     = true
  additional_recipients    = ["admin@contoso.com"]
}

# Replica Sets (High Availability)
replica_sets = [
  {
    location      = "North Europe"
    subnet_id     = "/subscriptions/.../subnets/replica-subnet"
  }
]
```

## Variable Reference

### Domain Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `domain_name` | string | **required** | The DNS domain name |
| `domain_display_name` | string | **required** | Display name for the domain |
| `forest_type` | string | `"User"` | Forest type: User or ResourceForest |
| `sku` | string | `"Standard"` | SKU: Standard, Enterprise, Premium |

### Network Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `virtual_network_name` | string | **required** | Virtual network name |
| `address_space` | list(string) | **required** | VNet address space |
| `subnet_name` | string | **required** | Subnet name |
| `subnet_address_prefix` | string | **required** | Subnet CIDR |

### Security Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `secure_ldap_enabled` | bool | `false` | Enable secure LDAP |
| `secure_ldap_external_access` | bool | `false` | Allow external LDAP access |
| `secure_ldap_certificate_pfx` | string | `null` | PFX certificate for LDAPS |
| `secure_ldap_certificate_password` | string | `null` | Certificate password |

### Synchronization Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `filtered_sync_enabled` | bool | `false` | Enable filtered synchronization |
| `filtered_sync_groups` | list(string) | `[]` | Groups to synchronize |

### Monitoring Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `log_analytics_workspace_name` | string | computed | Log Analytics workspace name |
| `log_analytics_retention_days` | number | `30` | Log retention period |
| `enable_diagnostic_settings` | bool | `true` | Enable diagnostic logging |

### High Availability Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `replica_sets` | list(object) | `[]` | Additional replica sets |

## Environment-Specific Configurations

### Development Environment

```hcl
# terraform.tfvars for development
resource_group_name = "rg-entradomain-dev"
location           = "West Europe"
domain_name        = "dev.contoso.local"
sku               = "Standard"

# Minimal network
address_space          = ["10.1.0.0/16"]
subnet_address_prefix  = "10.1.1.0/24"

# Basic security
secure_ldap_enabled = false
filtered_sync_enabled = true

# Minimal monitoring
log_analytics_retention_days = 7

tags = {
  Environment = "Development"
  Project     = "Authentication"
  Owner       = "Dev Team"
}
```

### Production Environment

```hcl
# terraform.tfvars for production
resource_group_name = "rg-entradomain-prod"
location           = "West Europe"
domain_name        = "contoso.local"
sku               = "Premium"

# Production network
address_space          = ["10.0.0.0/16"]
subnet_address_prefix  = "10.0.1.0/24"

# Enhanced security
secure_ldap_enabled = true
secure_ldap_external_access = false
filtered_sync_enabled = false

# High availability
replica_sets = [
  {
    location      = "North Europe"
    subnet_id     = "/subscriptions/.../resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/snet-replica"
  }
]

# Comprehensive monitoring
log_analytics_retention_days = 90
enable_diagnostic_settings = true

# Production notifications
notification_settings = {
  notify_dc_admins         = true
  notify_global_admins     = true
  additional_recipients    = [
    "ops-team@contoso.com",
    "security-team@contoso.com"
  ]
}

tags = {
  Environment = "Production"
  Project     = "Authentication"
  Owner       = "Infrastructure Team"
  CostCenter  = "IT-001"
  Compliance  = "SOX"
}
```

## SKU Comparison

### Standard SKU
- **Use Case**: Development, testing, small workloads
- **Features**:
  - Basic domain services
  - Single forest
  - Standard SLA
  - Basic monitoring

### Enterprise SKU
- **Use Case**: Production workloads, medium scale
- **Features**:
  - Advanced domain services
  - Forest trusts
  - Enhanced SLA
  - Advanced monitoring

### Premium SKU
- **Use Case**: Mission-critical, large scale
- **Features**:
  - All Enterprise features
  - Highest performance
  - Premium SLA
  - Comprehensive monitoring

## Network Planning

### Address Space Planning

```hcl
# Example for multi-environment setup
# Development: 10.1.0.0/16
# Staging:     10.2.0.0/16  
# Production:  10.0.0.0/16

# Subnet sizing guide:
# /24 - Up to 254 hosts (small)
# /23 - Up to 510 hosts (medium)
# /22 - Up to 1022 hosts (large)
```

### Network Security Groups

The template automatically creates NSG rules for:
- LDAP (389/tcp)
- LDAPS (636/tcp)
- PowerShell Remoting (5986/tcp)
- RDP (3389/tcp) - for management

### Custom NSG Rules

```hcl
# Add custom NSG rules in main.tf
resource "azurerm_network_security_rule" "custom_rule" {
  name                        = "AllowCustomApp"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8080"
  source_address_prefix      = "10.0.0.0/16"
  destination_address_prefix = "*"
  resource_group_name        = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.domain_services.name
}
```

## SSL Certificate Configuration

### For Secure LDAP (LDAPS)

1. **Generate Certificate**:
   ```powershell
   # Create self-signed certificate (development only)
   $cert = New-SelfSignedCertificate -DnsName "*.contoso.local" -CertStoreLocation "cert:\LocalMachine\My"
   
   # Export to PFX
   Export-PfxCertificate -Cert $cert -FilePath "domain.pfx" -Password (ConvertTo-SecureString -String "password" -Force -AsPlainText)
   ```

2. **Configure in terraform.tfvars**:
   ```hcl
   secure_ldap_enabled = true
   secure_ldap_certificate_pfx = base64encode(file("domain.pfx"))
   secure_ldap_certificate_password = "password"
   ```

### Production Certificate Requirements
- **Subject**: Must match domain name
- **Key Usage**: Digital Signature, Key Encipherment
- **Enhanced Key Usage**: Server Authentication
- **Validity**: Minimum 1 year

## Monitoring Configuration

### Log Analytics Workspace

```hcl
# Custom workspace configuration
log_analytics_workspace_name = "law-entradomain-prod"
log_analytics_retention_days = 90

# Performance counters
performance_counters = [
  "\\Process(*)\\% Processor Time",
  "\\Memory\\Available MBytes",
  "\\LogicalDisk(*)\\Disk Read Bytes/sec"
]

# Event logs
windows_event_logs = [
  "System",
  "Application", 
  "Security",
  "Directory Service"
]
```

### Custom Alerts

```hcl
# Add to monitoring.tf
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "high-cpu-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azapi_resource.domain_service.id]
  description         = "Action will be triggered when CPU usage is greater than 80%"

  criteria {
    metric_namespace = "Microsoft.AAD/DomainServices"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

## Backup and Recovery

### Automated Backups
- **Frequency**: Daily
- **Retention**: Based on SKU
- **Scope**: Full forest backup

### Manual Backup Configuration

```hcl
# Add backup storage account
resource "azurerm_storage_account" "backup" {
  name                     = "stbackup${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  account_tier            = "Standard"
  account_replication_type = "GRS"
  
  backup_policy_id = azurerm_backup_policy_file_share.main.id
}
```

## Validation and Testing

### Configuration Validation

```bash
# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Check formatting
terraform fmt -check=true

# Security scan
checkov -f main.tf
```

### Post-Deployment Testing

```powershell
# Test LDAP connectivity
Test-NetConnection -ComputerName "contoso.local" -Port 389

# Test LDAPS connectivity
Test-NetConnection -ComputerName "contoso.local" -Port 636

# Verify domain join
Add-Computer -DomainName "contoso.local" -Credential (Get-Credential)
```

## Troubleshooting Configuration

### Common Issues

1. **Invalid Domain Name**
   - Must be valid DNS name
   - Cannot be public domain
   - Must be 3-64 characters

2. **Network Conflicts**
   - Check address space overlaps
   - Verify subnet sizing
   - Confirm NSG rules

3. **Certificate Issues**
   - Verify PFX format
   - Check password
   - Confirm DNS names

### Validation Commands

```bash
# Check configuration syntax
terraform validate

# Verify variable values
terraform console
> var.domain_name
> var.address_space

# Test network connectivity
nslookup contoso.local
ping contoso.local
```