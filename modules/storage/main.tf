###############################################################################
# Storage Account
# - Public network access disabled
# - Reached exclusively through a Private Endpoint to the blob sub-resource
# - DNS A record is registered automatically by the hub's central automation
#   into privatelink.blob.core.windows.net
###############################################################################

resource "azurerm_storage_account" "media" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # Block all public traffic — only private endpoints reach this account.
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # force Entra ID / MI auth, no account keys

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # CKV_AZURE_33: queue logging — we don't use the Queue service, only Blob.
  # Checkov fires on the account level regardless. Suppressed with justification.
  #checkov:skip=CKV_AZURE_33:Queue service not used; only Blob storage is in scope for this workload

  # CKV_AZURE_206: checkov expects GRS/GZRS. ZRS is intentional: it gives
  # synchronous 3-AZ redundancy within the region — sufficient for a
  # single-region deployment and cheaper than cross-region replication.
  # For a DR requirement, promote to GZRS in the relevant environment's tfvars.
  #checkov:skip=CKV_AZURE_206:ZRS chosen deliberately for single-region HA; upgrade to GZRS if cross-region DR is required

  tags = var.tags
}

resource "azurerm_storage_container" "media" {
  name                  = "media"
  storage_account_id    = azurerm_storage_account.media.id
  container_access_type = "private"
}

###############################################################################
# Private Endpoint (blob sub-resource)
###############################################################################
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pep-${azurerm_storage_account.media.name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.media.name}-blob"
    private_connection_resource_id = azurerm_storage_account.media.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  # No private_dns_zone_group: A records are created by the hub's
  # central DNS automation (Azure Policy / Event Grid based).
}

###############################################################################
# Least-privilege: app MI gets data-plane Blob access only — no control-plane.
###############################################################################
resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.media.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.app_principal_id
}
