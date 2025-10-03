# Microsoft Entra Domain Services Terraform Template

A comprehensive Terraform template for deploying Microsoft Entra Domain Services (formerly Azure AD Domain Services) into Azure, providing a secure authentication infrastructure building block.

## 📋 Quick Links

- [📖 **Full Documentation**](docs/README.md) - Comprehensive deployment guide
- [🚀 **Deployment Summary**](docs/DEPLOYMENT_SUMMARY.md) - Project overview and features
- [🏗️ **Architecture Guide**](docs/ARCHITECTURE.md) - Technical architecture details
- [🔧 **Configuration Guide**](docs/CONFIGURATION.md) - Configuration options and examples
- [🔍 **Troubleshooting**](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [🛡️ **Security Guide**](docs/SECURITY.md) - Security best practices and compliance

## ⚡ Quick Start

1. **Clone and Configure**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

2. **Deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## 🌟 Key Features

- ✅ **Complete Domain Services Setup**: Fully configured Entra Domain Services instance
- ✅ **Network Security**: Dedicated subnet with Network Security Groups
- ✅ **High Availability**: Support for replica sets across multiple regions
- ✅ **Secure LDAP**: Optional secure LDAP configuration with certificate management
- ✅ **Monitoring & Diagnostics**: Comprehensive logging and alerting
- ✅ **Security Best Practices**: Key Vault integration, encrypted communications
- ✅ **CI/CD Ready**: GitHub Actions and Azure DevOps pipelines included

## 📋 Prerequisites

- Azure Subscription with Contributor/Owner permissions
- Azure AD Tenant with Global Administrator rights
- Terraform v1.5.0+
- Valid domain name

## 🚀 CI/CD Integration

### Local Development
```bash
# Use Makefile for common tasks
make test       # Run all validations
make format     # Format code
make security   # Security scan
make docs       # Generate documentation
```

### Automated Pipelines
- **GitHub Actions**: Automatic validation, security scanning, and documentation
- **Azure DevOps**: Multi-stage pipeline with compliance checks
- **Pre-commit Hooks**: Quality gates for local development

## 📁 Project Structure

```
├── main.tf                     # Core Terraform configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── monitoring.tf               # Security and monitoring
├── terraform.tfvars.example    # Example configuration
├── Makefile                    # Development commands
├── .github/workflows/          # GitHub Actions
├── azure-pipelines.yml         # Azure DevOps pipeline
├── .pre-commit-config.yaml     # Pre-commit hooks
└── docs/                       # Documentation
    ├── README.md               # Full documentation
    ├── DEPLOYMENT_SUMMARY.md   # Project overview
    ├── ARCHITECTURE.md         # Architecture details
    ├── CONFIGURATION.md        # Configuration guide
    ├── TROUBLESHOOTING.md      # Troubleshooting guide
    └── SECURITY.md             # Security best practices
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `make test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 References

- [Azure AD Domain Services Documentation](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure AD Provider](https://registry.terraform.io/providers/hashicorp/azuread/latest)