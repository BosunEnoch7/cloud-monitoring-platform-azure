output "virtual_machine_id" {
  description = "Resource ID of the Ubuntu virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "virtual_machine_name" {
  description = "Name of the Ubuntu virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip_address" {
  description = "Static public IPv4 address assigned to the monitoring host."
  value       = azurerm_public_ip.this.ip_address
}

output "private_ip_address" {
  description = "Private IPv4 address assigned to the monitoring host."
  value       = azurerm_network_interface.this.private_ip_address
}

output "principal_id" {
  description = "Object ID of the VM system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
