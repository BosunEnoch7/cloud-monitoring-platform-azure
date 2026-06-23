output "deployment_context" {
  description = "Non-sensitive naming and placement context for the development environment."
  value = {
    environment = var.environment
    location    = var.location
    region_rg   = azurerm_resource_group.this.name
    name_prefix = local.name_prefix
  }
}

output "resource_group_name" {
  description = "Name of the Azure resource group."
  value       = azurerm_resource_group.this.name
}

output "virtual_network_name" {
  description = "Name of the Azure virtual network."
  value       = module.network.virtual_network_name
}

output "monitoring_subnet_id" {
  description = "Resource ID of the subnet reserved for monitoring workloads."
  value       = module.network.subnet_id
}

output "virtual_machine_name" {
  description = "Name of the Ubuntu monitoring virtual machine."
  value       = module.compute.virtual_machine_name
}

output "public_ip_address" {
  description = "Static public IPv4 address of the monitoring host."
  value       = module.compute.public_ip_address
}

output "ssh_command" {
  description = "Convenience command for SSH access from a trusted source CIDR."
  value       = "ssh ${var.admin_username}@${module.compute.public_ip_address}"
}
