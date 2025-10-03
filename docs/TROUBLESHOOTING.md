# Troubleshooting Guide

## Overview

This guide helps diagnose and resolve common issues with the Microsoft Entra Domain Services Terraform deployment.

## Quick Diagnostics

### Health Check Commands

```bash
# Check Terraform state
terraform show
terraform state list

# Validate configuration
terraform validate
terraform plan

# CI/CD testing (no Azure auth required)
ARM_SKIP_PROVIDER_REGISTRATION=true ARM_USE_CLI=false terraform plan -var-file="terraform.tfvars.ci"

# Check Azure resources
az login
az account show
az group show --name "rg-entradomain-prod"
```

### Common Status Checks

```powershell
# Network connectivity
Test-NetConnection -ComputerName "contoso.local" -Port 389
Test-NetConnection -ComputerName "contoso.local" -Port 636

# DNS resolution
nslookup contoso.local
Resolve-DnsName -Name contoso.local

# Domain services status
Get-ADDomainController -Discover -Domain "contoso.local"
```

## Deployment Issues

### 1. Terraform Validation Errors

#### Issue: Invalid Resource Provider
```
Error: Invalid resource type "azurerm_active_directory_domain_service"
```

**Solution**: Use AzAPI provider for Domain Services
```hcl
# Correct approach in main.tf
resource "azapi_resource" "domain_service" {
  type      = "Microsoft.AAD/DomainServices@2021-05-01"
  # ... configuration
}
```

#### Issue: Subnet Delegation Error
```
Error: Subnet delegation is not supported for Domain Services
```

**Solution**: Remove subnet delegation
```hcl
# Remove this block from subnet configuration
delegation {
  name = "Microsoft.AAD/domainServices"
  # ... 
}
```

#### Issue: Invalid Reference in Variable Validation
```
Error: Invalid reference in variable validation
The condition for variable "variable_name" can only refer to the variable itself
```

**Solution**: Variable validation conditions cannot reference other variables
```hcl
# ❌ Incorrect - referencing other variables
validation {
  condition = var.enable_feature == false || (var.enable_feature == true && length(var.other_variable) > 0)
  error_message = "Other variable is required when feature is enabled."
}

# ✅ Correct - only referencing the variable itself  
validation {
  condition = var.other_variable == "" || length(var.other_variable) >= 40
  error_message = "Variable must be at least 40 characters when provided."
}
```

#### Issue: Invalid Domain Name
```
Error: Domain name must be a valid DNS name
```

**Solution**: Use proper DNS naming
```hcl
# Correct format
domain_name = "contoso.local"     # ✓ Valid
domain_name = "contoso.com"       # ✗ Invalid (public domain)
domain_name = "contoso"           # ✗ Invalid (no TLD)
```

### 2. Provider Configuration Issues

#### Issue: AzAPI Provider Not Found
```
Error: Failed to instantiate provider "azapi"
```

**Solution**: Add AzAPI provider to required_providers
```hcl
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.10"
    }
  }
}
```

#### Issue: Insufficient Permissions
```
Error: Authorization failed when calling the Role Assignments API
```

**Solution**: Verify Azure AD permissions
```bash
# Check current user permissions
az ad user show --id $(az account show --query user.name -o tsv)

# Required roles:
# - Contributor (for Azure resources)
# - Global Administrator (for Azure AD)
```

### 3. Resource Creation Failures

#### Issue: Virtual Network Creation Failed
```
Error: A resource with the ID already exists
```

**Solution**: Check for existing resources
```bash
# List existing VNets
az network vnet list --query "[].{Name:name, ResourceGroup:resourceGroup}"

# Import existing resource if needed
terraform import azurerm_virtual_network.main /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/vnet-name
```

#### Issue: Key Vault Access Denied
```
Error: The client does not have permission to perform action on scope
```

**Solution**: Configure Key Vault access policy
```hcl
# Add to main.tf
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
  ]
}
```

## Network Issues

### 1. Connectivity Problems

#### Issue: Cannot Connect to LDAP
```
Test-NetConnection: TCP connect to contoso.local:389 failed
```

**Diagnostic Steps**:
```powershell
# Check NSG rules
az network nsg rule list --resource-group "rg-entradomain-prod" --nsg-name "nsg-domain-services"

# Verify subnet association
az network vnet subnet show --resource-group "rg-entradomain-prod" --vnet-name "vnet-entradomain" --name "snet-domain-services"

# Test from within VNet
Test-NetConnection -ComputerName "10.0.1.4" -Port 389
```

**Solutions**:
1. Verify NSG rules allow LDAP traffic
2. Check if source IP is in allowed range
3. Confirm domain services are healthy

#### Issue: LDAPS Connection Failed
```
Test-NetConnection: TCP connect to contoso.local:636 failed
```

**Diagnostic Steps**:
```bash
# Check secure LDAP configuration
az ad ds show --resource-group "rg-entradomain-prod" --name "contoso"

# Verify certificate validity
openssl s_client -connect contoso.local:636 -showcerts
```

**Solutions**:
1. Enable secure LDAP in configuration
2. Upload valid SSL certificate
3. Configure certificate properly

### 2. DNS Resolution Issues

#### Issue: Domain Name Not Resolving
```
nslookup: can't find contoso.local: Non-existent domain
```

**Diagnostic Steps**:
```powershell
# Check Azure DNS settings
az network private-dns zone list --resource-group "rg-entradomain-prod"

# Verify VNet DNS settings
az network vnet show --resource-group "rg-entradomain-prod" --name "vnet-entradomain" --query "dhcpOptions"
```

**Solutions**:
1. Configure custom DNS servers in VNet
2. Add DNS records for domain services
3. Update network adapter DNS settings

### 3. Subnet Configuration Issues

#### Issue: Insufficient IP Addresses
```
Error: No available IP addresses in subnet
```

**Solution**: Expand subnet or use larger CIDR
```hcl
# Change from /28 to /24
subnet_address_prefix = "10.0.1.0/24"  # 254 addresses instead of 14
```

#### Issue: Subnet Too Small
```
Error: Subnet must have at least 16 IP addresses
```

**Solution**: Use minimum /28 subnet
```hcl
# Minimum required size
subnet_address_prefix = "10.0.1.0/28"  # 16 addresses (14 usable)
```

## Authentication Issues

### 1. Domain Join Failures

#### Issue: Computer Cannot Join Domain
```
Add-Computer: The specified domain does not exist or cannot be contacted
```

**Diagnostic Steps**:
```powershell
# Test domain controller connectivity
nltest /dclist:contoso.local

# Check domain services health
Get-ADDomainController -Discover -Domain "contoso.local"

# Verify credentials
Test-ComputerSecureChannel -Server "contoso.local"
```

**Solutions**:
1. Verify domain services are running
2. Check network connectivity
3. Confirm proper DNS configuration
4. Use correct domain credentials

#### Issue: User Authentication Failed
```
Error: Logon failure: unknown user name or bad password
```

**Diagnostic Steps**:
```powershell
# Check user synchronization
Get-ADUser -Filter * -Server "contoso.local"

# Verify sync status
az ad ds show --resource-group "rg-entradomain-prod" --name "contoso" --query "syncScope"
```

**Solutions**:
1. Wait for user synchronization
2. Check filtered sync settings
3. Verify user exists in Azure AD

### 2. LDAP Authentication Issues

#### Issue: LDAP Bind Failed
```
ldap_bind: Invalid credentials (49)
```

**Diagnostic Steps**:
```bash
# Test LDAP bind
ldapsearch -H ldap://contoso.local -D "cn=admin,dc=contoso,dc=local" -W

# Check LDAP configuration
ldapsearch -H ldap://contoso.local -x -s base -b "" "(objectclass=*)" "*" +
```

**Solutions**:
1. Use correct LDAP credentials format
2. Verify LDAP is enabled
3. Check user permissions

## Performance Issues

### 1. Slow Response Times

#### Issue: High Latency
```
Response time > 5 seconds for authentication
```

**Diagnostic Steps**:
```bash
# Check resource utilization
az monitor metrics list --resource "/subscriptions/.../Microsoft.AAD/DomainServices/contoso"

# Monitor network latency
ping -t contoso.local
```

**Solutions**:
1. Add replica sets in user regions
2. Upgrade to higher SKU
3. Optimize network routing

#### Issue: High CPU Usage
```
CPU utilization consistently > 80%
```

**Solutions**:
1. Upgrade to Premium SKU
2. Optimize LDAP queries
3. Implement query caching

### 2. Capacity Issues

#### Issue: Connection Limits Reached
```
Error: Maximum number of connections exceeded
```

**Solutions**:
1. Implement connection pooling
2. Upgrade to higher SKU
3. Add replica sets

## Security Issues

### 1. Certificate Problems

#### Issue: SSL Certificate Invalid
```
SSL certificate verification failed
```

**Diagnostic Steps**:
```bash
# Check certificate details
openssl x509 -in certificate.crt -text -noout

# Verify certificate chain
openssl verify -CAfile ca-bundle.crt certificate.crt
```

**Solutions**:
1. Renew expired certificate
2. Install proper certificate chain
3. Update certificate configuration

#### Issue: Certificate Upload Failed
```
Error: Invalid PFX format or password
```

**Solutions**:
1. Verify PFX file format
2. Check password correctness
3. Regenerate certificate if needed

### 2. Access Control Issues

#### Issue: Unauthorized Access
```
Error: Access denied for user
```

**Solutions**:
1. Check Azure AD group membership
2. Verify RBAC assignments
3. Review conditional access policies

## Monitoring and Diagnostics

### 1. Log Analysis

#### Check Domain Services Logs
```bash
# Query Log Analytics
az monitor log-analytics query \
  --workspace "law-entradomain-prod" \
  --analytics-query "AuditLogs | where TimeGenerated > ago(1h)"
```

#### Common Log Queries
```kql
// Authentication failures
SecurityEvent
| where EventID == 4625
| summarize count() by Account, IpAddress

// High CPU usage
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where CounterValue > 80

// LDAP errors
Event
| where Source == "Microsoft-Windows-Directory-Services-SAM"
| where EventLevelName == "Error"
```

### 2. Health Monitoring

#### Azure Resource Health
```bash
# Check resource health
az resource show --ids "/subscriptions/.../Microsoft.AAD/DomainServices/contoso" --query "properties.health"

# View health history
az monitor activity-log list --resource-group "rg-entradomain-prod"
```

#### Custom Health Checks
```powershell
# PowerShell health check script
function Test-DomainServices {
    param($DomainName)
    
    try {
        # Test LDAP
        $ldap = Test-NetConnection -ComputerName $DomainName -Port 389
        
        # Test LDAPS
        $ldaps = Test-NetConnection -ComputerName $DomainName -Port 636
        
        # Test DNS
        $dns = Resolve-DnsName -Name $DomainName
        
        return @{
            LDAP = $ldap.TcpTestSucceeded
            LDAPS = $ldaps.TcpTestSucceeded
            DNS = $dns -ne $null
        }
    }
    catch {
        Write-Error "Health check failed: $_"
        return $false
    }
}

# Run health check
Test-DomainServices -DomainName "contoso.local"
```

## Recovery Procedures

### 1. Service Recovery

#### Restart Domain Services
```bash
# Azure CLI (if available)
az ad ds restart --resource-group "rg-entradomain-prod" --name "contoso"

# Or recreate via Terraform
terraform destroy -target=azapi_resource.domain_service
terraform apply -target=azapi_resource.domain_service
```

#### Backup and Restore
```bash
# Check backup status
az backup vault show --resource-group "rg-entradomain-prod" --name "rsv-entradomain"

# Restore from backup (if configured)
az backup restore restore-azureworkload --resource-group "rg-entradomain-prod" --vault-name "rsv-entradomain"
```

### 2. Network Recovery

#### Reset Network Configuration
```hcl
# Recreate network components
terraform destroy -target=azurerm_network_security_group.domain_services
terraform destroy -target=azurerm_subnet.domain_services
terraform apply
```

### 3. Complete Recovery

#### Full Environment Recreation
```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Destroy and recreate
terraform destroy
terraform apply

# Verify deployment
terraform validate
terraform plan
```

## Getting Help

### Microsoft Support
- **Azure Support**: Create support ticket in Azure portal
- **Documentation**: [Azure AD Domain Services docs](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/)
- **Community**: [Microsoft Q&A](https://docs.microsoft.com/en-us/answers/)

### Terraform Support
- **Registry**: [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/)
- **Issues**: [GitHub Issues](https://github.com/hashicorp/terraform-provider-azurerm/issues)
- **Community**: [Terraform Community Forum](https://discuss.hashicorp.com/)

### Emergency Contacts
```yaml
# Define in your organization
On-Call Team: +1-xxx-xxx-xxxx
Azure Support: Portal ticket system
Security Team: security@company.com
Infrastructure Team: infra@company.com
```