locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.additional_tags,
    {
      environment = var.environment
      managed_by  = "terraform"
      project     = var.project_name
      owner       = var.owner
    }
  )
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "../../modules/network"

  name_prefix             = local.name_prefix
  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  vnet_address_space      = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes
  admin_source_cidrs      = var.admin_source_cidrs
  tags                    = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = module.network.subnet_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  vm_size             = var.vm_size
  os_disk_size_gb     = var.os_disk_size_gb
  ubuntu_image        = var.ubuntu_image
  tags                = local.common_tags
}
