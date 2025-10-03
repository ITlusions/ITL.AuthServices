# Security Guide

## Overview

This guide outlines security best practices, compliance considerations, and security controls for the Microsoft Entra Domain Services deployment.

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Boundary                       │
├─────────────────────────────────────────────────────────────┤
│  1. Azure AD Conditional Access                            │
│  2. Network Security Groups                                │
│  3. Private Virtual Network                                │
│  4. Subnet Isolation                                       │
│  5. Service Endpoints                                      │
│  6. Encrypted Communications (TLS/SSL)                     │
│  7. Azure AD Authentication                                │
│  8. Role-Based Access Control (RBAC)                       │
│  9. Key Vault Secret Management                            │
│  10. Comprehensive Audit Logging                           │
└─────────────────────────────────────────────────────────────┘
```

## Network Security

### Network Security Groups (NSG)

#### Inbound Rules (Restrictive)
```hcl
# LDAP - Internal only
resource "azurerm_network_security_rule" "allow_ldap" {
  name                       = "AllowLDAP"
  priority                   = 1000
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range         = "*"
  destination_port_range    = "389"
  source_address_prefixes   = var.allowed_source_addresses
  destination_address_prefix = var.subnet_address_prefix
}

# LDAPS - Secure LDAP
resource "azurerm_network_security_rule" "allow_ldaps" {
  name                       = "AllowLDAPS"
  priority                   = 1001
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range         = "*"
  destination_port_range    = "636"
  source_address_prefixes   = var.allowed_source_addresses
  destination_address_prefix = var.subnet_address_prefix
}

# Management - Restricted source IPs
resource "azurerm_network_security_rule" "allow_management" {
  name                       = "AllowManagement"
  priority                   = 1100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range         = "*"
  destination_port_ranges   = ["3389", "5986"]
  source_address_prefixes   = var.management_source_addresses
  destination_address_prefix = var.subnet_address_prefix
}

# Deny all other traffic
resource "azurerm_network_security_rule" "deny_all" {
  name                       = "DenyAllInbound"
  priority                   = 4096
  direction                  = "Inbound"
  access                     = "Deny"
  protocol                   = "*"
  source_port_range         = "*"
  destination_port_range    = "*"
  source_address_prefix     = "*"
  destination_address_prefix = "*"
}
```

#### Outbound Rules (Controlled)
```hcl
# Allow Azure AD sync
resource "azurerm_network_security_rule" "allow_azure_ad_sync" {
  name                       = "AllowAzureADSync"
  priority                   = 1000
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range         = "*"
  destination_port_ranges   = ["443", "80"]
  source_address_prefix     = var.subnet_address_prefix
  destination_address_prefix = "AzureActiveDirectory"
}

# Allow monitoring
resource "azurerm_network_security_rule" "allow_monitoring" {
  name                       = "AllowMonitoring"
  priority                   = 1001
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range         = "*"
  destination_port_range    = "443"
  source_address_prefix     = var.subnet_address_prefix
  destination_address_prefix = "AzureMonitor"
}
```

### Private Networking

#### Service Endpoints
```hcl
# Enable service endpoints for security
resource "azurerm_subnet" "domain_services" {
  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.AzureActiveDirectory"
  ]
}
```

#### Private DNS
```hcl
# Private DNS zone for internal resolution
resource "azurerm_private_dns_zone" "domain" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "domain" {
  name                  = "domain-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.domain.name
  virtual_network_id    = azurerm_virtual_network.main.id
}
```

## Identity and Access Management

### Azure AD Integration

#### Security Groups
```hcl
# Domain Admins group
resource "azuread_group" "domain_admins" {
  display_name     = "Domain Admins - ${var.domain_name}"
  description      = "Administrators for ${var.domain_name} domain services"
  security_enabled = true

  members = var.domain_admin_users
}

# Domain Users group
resource "azuread_group" "domain_users" {
  display_name     = "Domain Users - ${var.domain_name}"
  description      = "Standard users for ${var.domain_name} domain services"
  security_enabled = true
}
```

#### Service Principals
```hcl
# Service principal for domain services
resource "azuread_application" "domain_services" {
  display_name = "Domain Services - ${var.domain_name}"
  
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    
    resource_access {
      id   = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9" # Application.ReadWrite.All
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "domain_services" {
  application_id = azuread_application.domain_services.application_id
}
```

### Role-Based Access Control (RBAC)

#### Custom Roles
```hcl
# Domain Services Operator role
resource "azurerm_role_definition" "domain_services_operator" {
  name        = "Domain Services Operator"
  scope       = azurerm_resource_group.main.id
  description = "Manage domain services resources"

  permissions {
    actions = [
      "Microsoft.AAD/domainServices/read",
      "Microsoft.AAD/domainServices/write",
      "Microsoft.AAD/domainServices/restart/action",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/networkSecurityGroups/read"
    ]
    
    not_actions = [
      "Microsoft.AAD/domainServices/delete"
    ]
  }
}

# Assign role to operations team
resource "azurerm_role_assignment" "domain_services_operator" {
  scope              = azurerm_resource_group.main.id
  role_definition_id = azurerm_role_definition.domain_services_operator.role_definition_resource_id
  principal_id       = azuread_group.domain_admins.object_id
}
```

## Encryption and Certificate Management

### Key Vault Configuration

#### Secure Key Vault Setup
```hcl
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.domain_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "premium"

  # Security features
  enable_rbac_authorization   = true
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90

  # Network access
  public_network_access_enabled = false
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.domain_services.id
    ]
  }
}
```

#### Certificate Management
```hcl
# SSL certificate for LDAPS
resource "azurerm_key_vault_certificate" "ldaps" {
  name         = "ldaps-certificate"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_actions {
      action {
        action_type = "AutoRenew"
      }
      
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "digitalSignature",
        "keyEncipherment"
      ]

      subject            = "CN=*.${var.domain_name}"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          var.domain_name,
          "*.${var.domain_name}"
        ]
      }
    }
  }
}
```

### Secure LDAP Configuration

#### LDAPS Implementation
```hcl
# Secure LDAP configuration
locals {
  secure_ldap_config = {
    enabled                = var.secure_ldap_enabled
    external_access_enabled = var.secure_ldap_external_access
    certificate_thumbprint = var.secure_ldap_enabled ? azurerm_key_vault_certificate.ldaps.thumbprint : null
    certificate_pfx        = var.secure_ldap_enabled ? azurerm_key_vault_certificate.ldaps.certificate_data : null
  }
}
```

## Monitoring and Auditing

### Security Monitoring

#### Log Analytics Queries
```kql
// Failed authentication attempts
SecurityEvent
| where EventID == 4625
| where TimeGenerated > ago(1h)
| summarize FailedAttempts = count() by Account, IpAddress
| where FailedAttempts > 5

// Privileged account usage
SecurityEvent
| where EventID in (4672, 4648)
| where TimeGenerated > ago(24h)
| summarize Operations = count() by Account

// Network security violations
AzureNetworkAnalytics_CL
| where SubType_s == "FlowLog"
| where FlowStatus_s == "D" // Denied
| summarize DeniedConnections = count() by SrcIP_s, DestPort_d

// Domain services health
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AAD"
| where Category == "DomainServicesHealth"
| where Level == "Error"
```

#### Security Alerts
```hcl
# Failed authentication alert
resource "azurerm_monitor_scheduled_query_rule_alert" "failed_auth" {
  name                = "high-failed-auth-attempts"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  action {
    action_group           = [azurerm_monitor_action_group.security.id]
    email_subject          = "Security Alert: High Failed Authentication Attempts"
    custom_webhook_payload = "{}"
  }
  
  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when failed authentication attempts exceed threshold"
  enabled        = true
  
  query       = <<-QUERY
    SecurityEvent
    | where EventID == 4625
    | where TimeGenerated > ago(5m)
    | summarize FailedAttempts = count() by Account, IpAddress
    | where FailedAttempts > 10
  QUERY
  
  severity    = 2
  frequency   = 5
  time_window = 5
  
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}
```

### Compliance Monitoring

#### Azure Policy Integration
```hcl
# Require encryption in transit
resource "azurerm_policy_assignment" "require_encryption" {
  name                 = "require-encryption-in-transit"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  
  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Require diagnostic settings
resource "azurerm_policy_assignment" "require_diagnostics" {
  name                 = "require-diagnostic-settings"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9"
}
```

#### Security Center Integration
```hcl
# Security Center workspace
resource "azurerm_security_center_workspace" "main" {
  scope        = azurerm_resource_group.main.id
  workspace_id = azurerm_log_analytics_workspace.main.id
}

# Security Center contact
resource "azurerm_security_center_contact" "main" {
  email               = var.security_contact_email
  phone               = var.security_contact_phone
  alert_notifications = true
  alerts_to_admins    = true
}
```

## Backup and Recovery Security

### Secure Backup Configuration
```hcl
# Recovery Services Vault
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.resource_group_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  soft_delete_enabled = true
  
  # Immutable vault
  immutability = "Locked"
}

# Backup policy with encryption
resource "azurerm_backup_policy_vm" "main" {
  name                = "backup-policy-domain-services"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}
```

## Incident Response

### Security Runbooks

#### Automated Response
```hcl
# Logic App for automated response
resource "azurerm_logic_app_workflow" "security_response" {
  name                = "security-incident-response"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  workflow_schema    = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version   = "1.0.0.0"
  workflow_parameters = {}

  definition = jsonencode({
    triggers = {
      manual = {
        type = "Request"
        kind = "Http"
      }
    }
    actions = {
      isolate_compromised_account = {
        type = "Http"
        inputs = {
          method = "POST"
          uri    = "https://graph.microsoft.com/v1.0/users/@{triggerBody()['userId']}/revokeSignInSessions"
        }
      }
      notify_security_team = {
        type = "Http"
        inputs = {
          method = "POST"
          uri    = var.security_webhook_url
          body   = {
            alert    = "@{triggerBody()}"
            severity = "High"
          }
        }
      }
    }
  })
}
```

#### Manual Response Procedures
```powershell
# Emergency account lockout
function Lock-CompromisedAccount {
    param($UserPrincipalName)
    
    # Disable account
    Set-AzureADUser -ObjectId $UserPrincipalName -AccountEnabled $false
    
    # Revoke all sessions
    Revoke-AzureADUserAllRefreshToken -ObjectId $UserPrincipalName
    
    # Log incident
    Write-EventLog -LogName "Security" -Source "Domain Services" -EventId 5001 -Message "Account $UserPrincipalName locked due to security incident"
}

# Network isolation
function Isolate-DomainServices {
    # Create emergency NSG rule
    az network nsg rule create \
        --resource-group "rg-entradomain-prod" \
        --nsg-name "nsg-domain-services" \
        --name "Emergency-Deny-All" \
        --priority 100 \
        --direction Inbound \
        --access Deny \
        --protocol "*" \
        --source-address-prefixes "*" \
        --destination-address-prefixes "*"
}
```

## Security Baselines

### CIS Benchmark Compliance
- Enable secure LDAP with strong certificates
- Implement network segmentation
- Configure comprehensive logging
- Use strong authentication methods
- Regular security assessments

### NIST Framework Alignment
- **Identify**: Asset inventory and risk assessment
- **Protect**: Access controls and data protection
- **Detect**: Continuous monitoring and alerting
- **Respond**: Incident response procedures
- **Recover**: Backup and recovery processes

### SOC 2 Controls
- Access control management
- Network security monitoring
- Change management procedures
- Incident response documentation
- Regular security training

## Security Testing

### Penetration Testing
```bash
# Network scanning (authorized only)
nmap -sS -O target-domain.local

# LDAP enumeration
ldapsearch -H ldap://target-domain.local -x -s base -b "" "(objectclass=*)"

# SSL/TLS testing
sslscan target-domain.local:636
testssl.sh target-domain.local:636
```

### Vulnerability Assessment
```bash
# Security scanning with Nessus/OpenVAS
nessus-cli scan create --name "Domain Services Scan" --targets "10.0.1.0/24"

# Configuration assessment
# Run CIS benchmark tools
# Azure Security Center recommendations
# Terraform security scanning with Checkov
```

## Security Maintenance

### Regular Tasks
1. **Monthly**:
   - Review access logs
   - Update security documentation
   - Validate backup integrity
   - Test incident response procedures

2. **Quarterly**:
   - Security assessment
   - Certificate renewal check
   - Access review and cleanup
   - Update security baselines

3. **Annually**:
   - Penetration testing
   - Security architecture review
   - Disaster recovery testing
   - Security training updates

### Automation Scripts
```powershell
# Monthly security health check
function Invoke-SecurityHealthCheck {
    # Check certificate expiration
    $certs = Get-AzKeyVaultCertificate -VaultName "kv-entradomain"
    $expiring = $certs | Where-Object { $_.Expires -lt (Get-Date).AddDays(30) }
    
    # Review failed logins
    $failedLogins = Search-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query "SecurityEvent | where EventID == 4625 | where TimeGenerated > ago(30d)"
    
    # Generate report
    $report = @{
        ExpiringCertificates = $expiring
        FailedLogins = $failedLogins.Results.Count
        LastChecked = Get-Date
    }
    
    return $report
}
```