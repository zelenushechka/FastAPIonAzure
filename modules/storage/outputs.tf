output "storage_account_id" {
  value = azurerm_storage_account.media.id
}

output "storage_account_name" {
  value = azurerm_storage_account.media.name
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.media.primary_blob_endpoint
}

output "container_name" {
  value = azurerm_storage_container.media.name
}
