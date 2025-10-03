# Terraform configuration for Microsoft Entra Domain Services deployment
# This template creates a secure and properly configured Entra Domain Services instance

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

provider "azapi" {}

# Get current client configuration
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Generate random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group for Entra Domain Services
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${random_string.suffix.result}"
  location = var.location

  tags = merge(var.common_tags, {
    Purpose = "Entra Domain Services"
    Service = "Authentication"
  })
}

# Virtual Network for Domain Services
resource "azurerm_virtual_network" "main" {
  name                = "${var.vnet_name}-${random_string.suffix.result}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(var.common_tags, {
    Purpose = "Entra Domain Services Network"
  })
}

# Dedicated subnet for Domain Services (required)
resource "azurerm_subnet" "domain_services" {
  name                 = var.domain_services_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.domain_services_subnet_prefix]

  # Note: Azure AD Domain Services does not require explicit subnet delegation
  # The subnet should be dedicated to Domain Services only
}

# Network Security Group for Domain Services subnet
resource "azurerm_network_security_group" "domain_services" {
  name                = "${var.nsg_name}-${random_string.suffix.result}"
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

  # Allow PowerShell Remoting (if enabled)
  dynamic "security_rule" {
    for_each = var.enable_powershell_remoting ? [1] : []
    content {
      name                       = "AllowPSRemoting"
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5986"
      source_address_prefix      = var.management_source_address_prefix
      destination_address_prefix = "*"
    }
  }

  # Allow Windows Remote Management (if enabled)
  dynamic "security_rule" {
    for_each = var.enable_powershell_remoting ? [1] : []
    content {
      name                       = "AllowWinRM"
      priority                   = 1030
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5985"
      source_address_prefix      = var.management_source_address_prefix
      destination_address_prefix = "*"
    }
  }

  # Allow RDP (if enabled)
  dynamic "security_rule" {
    for_each = var.enable_rdp ? [1] : []
    content {
      name                       = "AllowRDP"
      priority                   = 1040
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = var.management_source_address_prefix
      destination_address_prefix = "*"
    }
  }

  tags = merge(var.common_tags, {
    Purpose = "Domain Services Security"
  })
}

# Associate NSG with Domain Services subnet
resource "azurerm_subnet_network_security_group_association" "domain_services" {
  subnet_id                 = azurerm_subnet.domain_services.id
  network_security_group_id = azurerm_network_security_group.domain_services.id
}

# Get Azure AD Domain Administrators group
data "azuread_group" "dc_administrators" {
  display_name     = "AAD DC Administrators"
  security_enabled = true
}

# Add users to Domain Administrators group
resource "azuread_group_member" "dc_administrators" {
  count            = length(var.domain_admin_users)
  group_object_id  = data.azuread_group.dc_administrators.object_id
  member_object_id = data.azuread_user.domain_admins[count.index].object_id
}

# Get domain admin users
data "azuread_user" "domain_admins" {
  count               = length(var.domain_admin_users)
  user_principal_name = var.domain_admin_users[count.index]
}

# Microsoft Entra Domain Services using AzAPI provider
resource "azapi_resource" "domain_services" {
  type      = "Microsoft.AAD/DomainServices@2022-12-01"
  name      = replace(var.domain_name, ".", "-")
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = jsonencode({
    properties = {
      domainName              = var.domain_name
      domainConfigurationType = var.domain_configuration_type
      sku                     = var.sku
      filteredSync            = var.sku == "Enterprise" ? var.filtered_sync : "Disabled"

      # Initial replica set (primary)
      replicaSets = concat([
        {
          subnetId = azurerm_subnet.domain_services.id
          location = azurerm_resource_group.main.location
        }
        ], [
        for idx, replica in var.replica_sets : {
          subnetId = replica.subnet_id != null ? replica.subnet_id : azurerm_subnet.replica_sets[idx].id
          location = replica.location
        }
      ])

      # Notification settings
      notificationSettings = {
        notifyGlobalAdmins   = var.notification_settings.notify_global_admins
        notifyDcAdmins       = var.notification_settings.notify_dc_admins
        additionalRecipients = var.notification_settings.additional_recipients
      }

      # Secure LDAP configuration
      ldapsSettings = var.enable_secure_ldap ? {
        ldaps                  = "Enabled"
        pfxCertificate         = base64encode(file("${path.module}/certificates/secure-ldap.pfx"))
        pfxCertificatePassword = var.secure_ldap_certificate_password
        externalAccess         = "Enabled"
        certificateThumbprint  = var.secure_ldap_certificate_thumbprint
        } : {
        ldaps = "Disabled"
      }
    }
  })

  tags = merge(var.common_tags, {
    Purpose = "Entra Domain Services"
    Service = "Authentication"
  })

  depends_on = [
    azurerm_subnet_network_security_group_association.domain_services,
    azuread_group_member.dc_administrators
  ]
}

# Create additional subnets for replica sets
resource "azurerm_subnet" "replica_sets" {
  count                = length(var.replica_sets)
  name                 = "snet-domain-services-replica-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.replica_sets[count.index].subnet_prefix]

  # Note: Azure AD Domain Services does not require explicit subnet delegation
  # The subnet should be dedicated to Domain Services only
}