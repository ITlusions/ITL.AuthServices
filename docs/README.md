# Microsoft Entra Domain Services Terraform Template

This Terraform template deploys Microsoft Entra Domain Services (formerly Azure AD Domain Services) into Azure, providing a comprehensive authentication infrastructure building block.

## Overview

Microsoft Entra Domain Services provides managed domain services such as domain join, group policy, LDAP, and Kerberos/NTLM authentication that are fully compatible with Windows Server Active Directory. This template creates a secure, production-ready deployment with best practices.

## Features

- ✅ **Complete Domain Services Setup**: Fully configured Entra Domain Services instance
- ✅ **Network Security**: Dedicated subnet with Network Security Groups
- ✅ **High Availability**: Support for replica sets across multiple regions
- ✅ **Secure LDAP**: Optional secure LDAP configuration with certificate management
- ✅ **Monitoring & Diagnostics**: Comprehensive logging and alerting
- ✅ **Security Best Practices**: Key Vault integration, encrypted communications
- ✅ **Backup Support**: Enterprise SKU backup configuration
- ✅ **Flexible Configuration**: Extensive customization options

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Resource Group                  │
├─────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────┐  │
│  │            Virtual Network                │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │     Domain Services Subnet          │  │  │
│  │  │  ┌─────────────────────────────┐    │  │  │
│  │  │  │   Entra Domain Services     │    │  │  │
│  │  │  │   - Primary Replica Set     │    │  │  │
│  │  │  │   - Domain Controllers      │    │  │  │
│  │  │  └─────────────────────────────┘    │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  │                                           │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │    Replica Set Subnets (Optional)   │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌───────────────┐  ┌─────────────────────────┐ │
│  │   Key Vault   │  │   Log Analytics         │ │
│  │   (Optional)  │  │   Workspace             │ │
│  └───────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Prerequisites

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Azure AD Tenant**: Azure AD tenant with Global Administrator rights
3. **Terraform**: Version 1.5.0 or later
4. **Azure CLI**: Authenticated with appropriate permissions
5. **Domain Name**: Valid domain name that you own or can manage

### Required Permissions

- **Azure Subscription**: Contributor or Owner role
- **Azure AD**: Global Administrator or sufficient permissions to:
  - Create and manage Azure AD Domain Services
  - Manage the "AAD DC Administrators" group
  - Read user information

## Quick Start

1. **Clone and Configure**:
   ```bash
   # Copy the example variables file
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit terraform.tfvars with your configuration
   # At minimum, update:
   # - domain_name
   # - domain_admin_users
   # - common_tags
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan
   ```

4. **Deploy**:
   ```bash
   terraform apply
   ```

## CI/CD Integration

This template includes comprehensive CI/CD pipelines for validation and security:

### GitHub Actions
- **Terraform Validation**: Automatic validation, formatting checks, and security scanning
- **Documentation Generation**: Auto-updates Terraform documentation
- **Cost Estimation**: Provides cost estimates for pull requests (requires Infracost API key)
- **Security Scanning**: Uses tfsec for Terraform security analysis

### Azure DevOps Pipeline
- **Multi-stage Pipeline**: Validation, documentation, and security compliance
- **Security Scanning**: Integrated tfsec and secret detection
- **Naming Convention Checks**: Validates Azure resource naming standards
- **Artifact Publishing**: Generates and publishes documentation artifacts

### Local Development
Use the included Makefile for local development:
```bash
# Check available commands
make help

# Run all validations
make test

# Format code
make format

# Security scan
make security

# Generate documentation
make docs
```

### Pre-commit Hooks
Install pre-commit hooks for automatic validation:
```bash
pip install pre-commit
pre-commit install
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `domain_name` | Domain name for the Domain Services | `"contoso.com"` |
| `domain_admin_users` | List of users to add to DC Administrators | `["admin@contoso.com"]` |

### Important Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `"West Europe"` | Azure region for deployment |
| `sku` | `"Standard"` | SKU (Standard or Enterprise) |
| `enable_secure_ldap` | `false` | Enable secure LDAP for external access |
| `enable_diagnostic_settings` | `true` | Enable monitoring and diagnostics |
| `filtered_sync` | `false` | Enable filtered sync (Enterprise only) |

### Network Configuration

The template creates a dedicated virtual network and subnet for Domain Services. You can customize:

- Virtual network address space
- Subnet addressing
- Network security group rules
- Source IP restrictions

### Security Features

1. **Network Security Groups**: Restrict access to LDAP/LDAPS ports
2. **Key Vault Integration**: Secure certificate and password storage
3. **Diagnostic Logging**: Comprehensive audit trails
4. **Encrypted Communications**: LDAPS support with certificate management
5. **Least Privilege Access**: Configurable source IP restrictions

## Post-Deployment Configuration

After successful deployment, complete these steps:

1. **Configure DNS**:
   - Note the Domain Controller IP addresses from the Azure portal
   - Update your virtual network DNS settings
   - Restart VMs for DNS changes to take effect

2. **Domain Join**:
   ```powershell
   # Example PowerShell command for domain join
   Add-Computer -DomainName "yourdomain.com" -Credential (Get-Credential)
   ```

3. **Test Authentication**:
   - Verify LDAP connectivity
   - Test user authentication
   - Validate group policy application

## High Availability

Configure replica sets for high availability across regions:

```hcl
replica_sets = [
  {
    location      = "North Europe"
    subnet_prefix = "10.1.2.0/24"
  }
]
```

## Secure LDAP Setup

To enable secure LDAP:

1. **Generate Certificate**:
   ```bash
   # Create certificate for your domain
   openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365
   # Convert to PFX format
   openssl pkcs12 -export -out secure-ldap.pfx -inkey key.pem -in cert.pem
   ```

2. **Configure Variables**:
   ```hcl
   enable_secure_ldap = true
   secure_ldap_certificate_thumbprint = "YOUR_CERT_THUMBPRINT"
   secure_ldap_certificate_password = "YOUR_CERT_PASSWORD"
   ```

3. **Place Certificate**:
   ```bash
   # Create certificates directory
   mkdir certificates
   # Copy your PFX file
   cp secure-ldap.pfx certificates/
   ```

## Monitoring and Alerts

The template includes comprehensive monitoring:

- **Diagnostic Settings**: All relevant log categories
- **Health Monitoring**: Domain Services health alerts
- **Action Groups**: Email notifications for critical events
- **Log Analytics**: Centralized log collection and analysis

## Backup Configuration

For Enterprise SKU deployments:

```hcl
sku = "Enterprise"
enable_backup = true
backup_retention_days = 30
```

## Troubleshooting

### Common Issues

1. **Permission Errors**:
   - Verify Azure AD Global Administrator rights
   - Check Azure subscription permissions

2. **Network Connectivity**:
   - Verify NSG rules allow required traffic
   - Check DNS configuration on client VMs

3. **Domain Join Failures**:
   - Ensure DNS points to Domain Controllers
   - Verify domain administrator credentials

### Useful Commands

```bash
# Check Terraform state
terraform state list

# View outputs
terraform output

# Destroy resources (careful!)
terraform destroy
```

## Cost Optimization

- **SKU Selection**: Use Standard SKU unless Enterprise features are needed
- **Replica Sets**: Only deploy in regions where needed
- **Monitoring**: Use Log Analytics workspace retention policies
- **Backup**: Configure appropriate retention periods

## Security Considerations

1. **Network Isolation**: Deploy in dedicated subnets
2. **Access Control**: Restrict source IP ranges
3. **Certificate Management**: Use Key Vault for certificate storage
4. **Monitoring**: Enable all diagnostic log categories
5. **Regular Updates**: Keep Terraform and providers updated

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review Azure AD Domain Services documentation
3. Open an issue in this repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## References

- [Azure AD Domain Services Documentation](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure AD Provider](https://registry.terraform.io/providers/hashicorp/azuread/latest)
- [Best Practices for Azure AD Domain Services](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/administration-concepts)