###############################################################################
# Azure Container Registry (Premium for Private Endpoint support)
# - Admin user disabled
# - Public network access disabled
# - Images pulled by the Container App via Private Endpoint (privatelink.azurecr.io)
###############################################################################

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium" # required for Private Endpoint
  admin_enabled       = false

  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"

  trust_policy_enabled     = true
  retention_policy_in_days = 30

  # CKV_AZURE_237 – dedicated data endpoints isolate the data plane (image
  # pulls) from the management plane at the DNS level.
  data_endpoint_enabled = true

  # CKV_AZURE_233 – zone redundancy distributes replicas across AZs.
  zone_redundancy_enabled = true

  # CKV_AZURE_166 – quarantine mode holds new images until a vulnerability
  # scanner (e.g. Defender for Containers) marks them verified.
  quarantine_policy_enabled = true

  # CKV_AZURE_165: geo-replication intentionally omitted.
  # This is a single-region private deployment; adding geo-replication would
  # require a second spoke VNet, peering, and DNS zone links — out of scope.
  #checkov:skip=CKV_AZURE_165:Single-region deployment by design

  tags = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pep-${azurerm_container_registry.this.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_container_registry.this.name}"
    private_connection_resource_id = azurerm_container_registry.this.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}

###############################################################################
# Least-privilege role grant for the Container App's MI: AcrPull only.
###############################################################################
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.app_principal_id
}
