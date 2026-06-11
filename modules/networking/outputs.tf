output "resource_group_name" {
  value = azurerm_resource_group.spoke.name
}

output "resource_group_id" {
  value = azurerm_resource_group.spoke.id
}

output "location" {
  value = azurerm_resource_group.spoke.location
}

output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "container_apps_subnet_id" {
  value = azurerm_subnet.container_apps.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
