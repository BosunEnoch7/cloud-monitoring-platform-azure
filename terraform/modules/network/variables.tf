variable "name_prefix" {
  description = "Validated project and environment prefix used to name network resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-42 lowercase letters, numbers, or hyphens and cannot start or end with a hyphen."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group that will contain network resources."
  type        = string
}

variable "location" {
  description = "Azure region for network resources."
  type        = string

  validation {
    condition     = var.location == "eastus"
    error_message = "The network module is currently standardized on eastus."
  }
}

variable "vnet_address_space" {
  description = "IPv4 CIDR blocks assigned to the virtual network."
  type        = list(string)

  validation {
    condition     = length(var.vnet_address_space) > 0 && alltrue([for cidr in var.vnet_address_space : can(cidrnetmask(cidr))])
    error_message = "vnet_address_space must contain at least one valid IPv4 CIDR block."
  }
}

variable "subnet_address_prefixes" {
  description = "IPv4 CIDR blocks assigned to the monitoring subnet."
  type        = list(string)

  validation {
    condition     = length(var.subnet_address_prefixes) > 0 && alltrue([for cidr in var.subnet_address_prefixes : can(cidrnetmask(cidr))])
    error_message = "subnet_address_prefixes must contain at least one valid IPv4 CIDR block."
  }
}

variable "admin_source_cidrs" {
  description = "Trusted public IPv4 CIDRs allowed to reach administrative endpoints."
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

variable "tags" {
  description = "Tags applied to supported network resources."
  type        = map(string)
}
