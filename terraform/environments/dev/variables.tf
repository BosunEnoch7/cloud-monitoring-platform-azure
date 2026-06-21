variable "subscription_id" {
  description = "Azure subscription ID in which the development environment will be created."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID-formatted Azure subscription ID."
  }
}

variable "project_name" {
  description = "Short, cloud-neutral project identifier used in resource names and tags."
  type        = string
  default     = "cloud-monitoring"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-22 lowercase letters, numbers, or hyphens and cannot start or end with a hyphen."
  }
}

variable "environment" {
  description = "Deployment environment identifier."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources in this environment."
  type        = string
  default     = "eastus"

  validation {
    condition     = var.location == "eastus"
    error_message = "This project currently standardizes all Azure resources in the eastus region."
  }
}

variable "owner" {
  description = "Owner recorded in Azure resource tags for accountability and cost reporting."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) >= 3
    error_message = "owner must contain at least three non-whitespace characters."
  }
}

variable "vnet_address_space" {
  description = "IPv4 CIDR blocks assigned to the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]

  validation {
    condition     = length(var.vnet_address_space) > 0 && alltrue([for cidr in var.vnet_address_space : can(cidrnetmask(cidr))])
    error_message = "vnet_address_space must contain at least one valid IPv4 CIDR block."
  }
}

variable "subnet_address_prefixes" {
  description = "IPv4 CIDR blocks assigned to the monitoring subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]

  validation {
    condition     = length(var.subnet_address_prefixes) > 0 && alltrue([for cidr in var.subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "subnet_address_prefixes must contain at least one valid IPv4 CIDR block."
  }
}

variable "admin_source_cidrs" {
  description = "Trusted public IPv4 CIDR blocks permitted to reach administrative endpoints. Never use 0.0.0.0/0."
  type        = list(string)

  validation {
    condition = (
      length(var.admin_source_cidrs) > 0 &&
      alltrue([for cidr in var.admin_source_cidrs : can(cidrnetmask(cidr))]) &&
      !contains(var.admin_source_cidrs, "0.0.0.0/0")
    )
    error_message = "admin_source_cidrs must contain valid IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "admin_username" {
  description = "Administrative username for the Ubuntu virtual machine."
  type        = string
  default     = "platformadmin"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{2,31}$", var.admin_username))
    error_message = "admin_username must be 3-32 lowercase characters and may contain numbers, underscores, or hyphens."
  }
}

variable "ssh_public_key" {
  description = "Public SSH key used to access the Ubuntu VM. This is not a private key."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+(?: .*)?$", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be a valid OpenSSH-format public key."
  }
}

variable "vm_size" {
  description = "Azure VM SKU for the monitoring host."
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "Size of the Ubuntu VM operating-system disk in GiB."
  type        = number
  default     = 64

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 256
    error_message = "os_disk_size_gb must be between 30 and 256 GiB."
  }
}

variable "ubuntu_image" {
  description = "Azure Marketplace image reference for the Ubuntu monitoring host."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  validation {
    condition = (
      var.ubuntu_image.publisher == "Canonical" &&
      var.ubuntu_image.offer == "0001-com-ubuntu-server-jammy" &&
      var.ubuntu_image.sku == "22_04-lts-gen2"
    )
    error_message = "The project currently standardizes compute on the Canonical Ubuntu 22.04 LTS Gen2 image."
  }
}

variable "additional_tags" {
  description = "Additional Azure resource tags merged with the mandatory project tags."
  type        = map(string)
  default     = {}
}
