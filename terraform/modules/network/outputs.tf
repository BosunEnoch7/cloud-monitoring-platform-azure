output "virtual_network_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_id" {
  description = "Resource ID of the monitoring subnet."
  value       = azurerm_subnet.monitoring.id
}

output "subnet_name" {
  description = "Name of the monitoring subnet."
  value       = azurerm_subnet.monitoring.name
}

output "network_security_group_id" {
  description = "Resource ID of the monitoring network security group."
  value       = azurerm_network_security_group.monitoring.id
}
