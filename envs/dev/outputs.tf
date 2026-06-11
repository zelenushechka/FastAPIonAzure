output "resource_group_name" {
  value = module.networking.resource_group_name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "container_app_fqdn" {
  value       = module.container_app.container_app_fqdn
  description = "Internal FQDN of the FastAPI app — resolves to a private IP from on-prem."
}

output "container_registry_login_server" {
  value = module.acr.login_server
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "key_vault_uri" {
  value = module.key_vault.key_vault_uri
}

output "app_managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.app.client_id
  description = "Use this for DefaultAzureCredential / ManagedIdentityCredential."
}

output "app_managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.app.principal_id
}
