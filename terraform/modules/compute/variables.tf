variable "name_prefix" {
  description = "Validated project and environment prefix used to name compute resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-42 lowercase letters, numbers, or hyphens and cannot start or end with a hyphen."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group that will contain compute resources."
  type        = string
}

variable "location" {
  description = "Azure region for compute resources."
  type        = string

  validation {
    condition     = contains(["eastus", "eastus2"], var.location)
    error_message = "The compute module currently supports eastus and eastus2."
  }
}

variable "availability_zone" {
  description = "Availability zone for the VM and its public IP."
  type        = string

  validation {
    condition     = contains(["1", "2", "3"], var.availability_zone)
    error_message = "availability_zone must be 1, 2, or 3."
  }
}

variable "subnet_id" {
  description = "Resource ID of the subnet to which the VM network interface will attach."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/.+/subnets/.+$", var.subnet_id))
    error_message = "subnet_id must be an Azure subnet resource ID."
  }
}

variable "admin_username" {
  description = "Administrative username for the Ubuntu VM."
  type        = string

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{2,31}$", var.admin_username))
    error_message = "admin_username must be 3-32 lowercase characters and may contain numbers, underscores, or hyphens."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH-format public key used for VM administration."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+(?: .*)?$", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be a valid OpenSSH-format public key."
  }
}

variable "vm_size" {
  description = "Azure VM SKU for the monitoring host."
  type        = string

  validation {
    condition     = length(trimspace(var.vm_size)) > 0
    error_message = "vm_size cannot be empty."
  }
}

variable "os_disk_size_gb" {
  description = "Size of the Ubuntu VM operating-system disk in GiB."
  type        = number

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 256
    error_message = "os_disk_size_gb must be between 30 and 256 GiB."
  }
}

variable "ubuntu_image" {
  description = "Azure Marketplace image reference for the Ubuntu VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "tags" {
  description = "Tags applied to supported compute resources."
  type        = map(string)
}
