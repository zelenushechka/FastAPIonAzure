###############################################################################
# Key Vault
# - RBAC authorization (no access policies)
# - Public network access disabled
# - Reached via Private Endpoint to the "vault" sub-resource
###############################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

###############################################################################
# Private Endpoint (vault sub-resource)
###############################################################################
resource "azurerm_private_endpoint" "kv" {
  name                = "pep-${azurerm_key_vault.this.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.this.name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

###############################################################################
# Demo placeholder secret
# CKV_AZURE_41  – expiration_date set to 1 year; rotation pipeline should
#                 update the value and bump the date before it expires.
# CKV_AZURE_114 – content_type documents what format consumers should expect.
###############################################################################
resource "azurerm_key_vault_secret" "app_api_key" {
  count        = var.create_demo_secret ? 1 : 0
  name         = "fastapi-app-api-key"
  value        = "REPLACE_ME_VIA_ROTATION_PIPELINE"
  key_vault_id = azurerm_key_vault.this.id
  content_type = "text/plain"

  # Rotate annually; the rotation pipeline should update value + expiration.
  expiration_date = timeadd(timestamp(), "8760h") # 365 days

  lifecycle {
    ignore_changes = [
      value,          # managed out-of-band by the rotation pipeline
      expiration_date # bumped by rotation, not Terraform
    ]
  }
}

###############################################################################
# Least-privilege: app MI reads secrets only — no key or certificate access.
###############################################################################
resource "azurerm_role_assignment" "app_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_principal_id
}
