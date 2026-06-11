output "container_app_id" {
  value = azurerm_container_app.this.id
}

output "container_app_name" {
  value = azurerm_container_app.this.name
}

output "container_app_fqdn" {
  value       = azurerm_container_app.this.latest_revision_fqdn
  description = "Internal FQDN of the app (resolves to a private IP via hub DNS)."
}

output "environment_id" {
  value = azurerm_container_app_environment.this.id
}

output "environment_static_ip" {
  value = azurerm_container_app_environment.this.static_ip_address
}
