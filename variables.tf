# Variables for Microsoft Entra Domain Services Terraform deployment

# General Configuration
variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "West Europe"

  validation {
    condition = contains([
      "eastus", "eastus2", "westus", "westus2", "westus3", "centralus", "northcentralus", "southcentralus",
      "westcentralus", "canadacentral", "canadaeast", "brazilsouth", "northeurope", "westeurope",
      "francecentral", "uksouth", "ukwest", "germanywestcentral", "switzerlandnorth", "norwayeast",
      "eastasia", "southeastasia", "japaneast", "japanwest", "australiaeast", "australiasoutheast",
      "southindia", "centralindia", "koreacentral", "southafricanorth", "uaenorth"
    ], var.location)
    error_message = "The location must be a valid Azure region."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for Entra Domain Services"
  type        = string
  default     = "rg-entraid-domain-services"

  validation {
    condition     = length(var.resource_group_name) >= 1 && length(var.resource_group_name) <= 80
    error_message = "Resource group name must be between 1 and 80 characters."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "Authentication Infrastructure"
    Owner       = "IT Operations"
    CostCenter  = "IT"
  }
}

# Network Configuration
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-entraid-domain-services"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "The vnet_address_space must be a valid CIDR block."
  }
}

variable "domain_services_subnet_name" {
  description = "Name of the subnet dedicated to Domain Services"
  type        = string
  default     = "snet-domain-services"
}

variable "domain_services_subnet_prefix" {
  description = "Address prefix for the Domain Services subnet"
  type        = string
  default     = "10.1.1.0/24"

  validation {
    condition     = can(cidrhost(var.domain_services_subnet_prefix, 0))
    error_message = "The domain_services_subnet_prefix must be a valid CIDR block."
  }
}

variable "nsg_name" {
  description = "Name of the Network Security Group for Domain Services"
  type        = string
  default     = "nsg-domain-services"
}

# Domain Configuration
variable "domain_name" {
  description = "The domain name for the Entra Domain Services (e.g., contoso.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN format (e.g., contoso.com)."
  }
}

variable "replica_sets" {
  description = "Configuration for replica sets (for high availability across regions)"
  type = list(object({
    location      = string
    subnet_id     = optional(string)
    subnet_prefix = optional(string)
  }))
  default = []

  validation {
    condition     = length(var.replica_sets) <= 5
    error_message = "Maximum of 5 replica sets are supported."
  }
}

# Security Configuration
variable "sku" {
  description = "SKU for the Domain Services (Standard or Enterprise)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Enterprise"], var.sku)
    error_message = "SKU must be either 'Standard' or 'Enterprise'."
  }
}

variable "filtered_sync" {
  description = "Enable filtered synchronization (Enterprise SKU only)"
  type        = bool
  default     = false
}

variable "domain_configuration_type" {
  description = "Type of domain configuration (FullySynced or ResourceTrusting)"
  type        = string
  default     = "FullySynced"

  validation {
    condition     = contains(["FullySynced", "ResourceTrusting"], var.domain_configuration_type)
    error_message = "Domain configuration type must be either 'FullySynced' or 'ResourceTrusting'."
  }
}

variable "ldap_source_address_prefix" {
  description = "Source address prefix allowed for LDAP/LDAPS connections"
  type        = string
  default     = "VirtualNetwork"
}

variable "management_source_address_prefix" {
  description = "Source address prefix allowed for management connections (RDP/PowerShell)"
  type        = string
  default     = "VirtualNetwork"
}

variable "enable_powershell_remoting" {
  description = "Enable PowerShell remoting access to domain controllers"
  type        = bool
  default     = false
}

variable "enable_rdp" {
  description = "Enable RDP access to domain controllers"
  type        = bool
  default     = false
}

# Secure LDAP Configuration
variable "enable_secure_ldap" {
  description = "Enable secure LDAP (LDAPS) for external access"
  type        = bool
  default     = false
}

variable "secure_ldap_certificate_thumbprint" {
  description = "Certificate thumbprint for secure LDAP (required if secure LDAP is enabled)"
  type        = string
  default     = ""

  validation {
    condition = var.enable_secure_ldap == false || (var.enable_secure_ldap == true && length(var.secure_ldap_certificate_thumbprint) > 0)
    error_message = "Certificate thumbprint is required when secure LDAP is enabled."
  }
}

variable "secure_ldap_certificate_password" {
  description = "Password for the secure LDAP certificate (sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

# Notification Configuration
variable "notification_settings" {
  description = "Email notification settings"
  type = object({
    notify_global_admins = optional(bool, true)
    notify_dc_admins     = optional(bool, true)
    additional_recipients = optional(list(string), [])
  })
  default = {
    notify_global_admins  = true
    notify_dc_admins      = true
    additional_recipients = []
  }
}

# Domain Administrator Configuration
variable "domain_admin_users" {
  description = "List of user principal names to be added to the 'AAD DC Administrators' group"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for user in var.domain_admin_users : can(regex("^[^@]+@[^@]+\\.[^@]+$", user))
    ])
    error_message = "All domain admin users must be valid email addresses."
  }
}

# Monitoring and Diagnostics
variable "enable_diagnostic_settings" {
  description = "Enable diagnostic settings for Domain Services"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings (if empty, workspace will be created)"
  type        = string
  default     = ""
}

variable "diagnostic_log_categories" {
  description = "List of log categories to enable for diagnostics"
  type        = list(string)
  default = [
    "SystemSecurity",
    "AccountManagement",
    "LogonLogoff",
    "ObjectAccess",
    "PolicyChange",
    "PrivilegeUse",
    "DetailTracking",
    "DirectoryServiceAccess",
    "AccountLogon"
  ]
}

# Backup and Recovery
variable "enable_backup" {
  description = "Enable backup for Domain Services (Enterprise SKU only)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}