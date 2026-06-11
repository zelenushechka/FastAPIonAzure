###############################################################################
# Non-secret values committed to git.
# Sensitive values (subscription ID, tenant ID, client ID) are supplied at
# runtime via TF_VAR_* environment variables set by GitHub Actions OIDC.
###############################################################################

location            = "westeurope"
environment         = "dev"
app_name            = "fastapi"
resource_group_name = "rg-usecase-private-dev"

# --- Hub references (placeholders — replace with platform-team values) ------
hub_vnet_id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-prod/providers/Microsoft.Network/virtualNetworks/vnet-hub-prod-01"
hub_vnet_name               = "vnet-hub-prod-01"
hub_resource_group_name     = "rg-hub-prod"
hub_dns_resource_group_name = "rg-hub-dns-prod"

hub_private_dns_zone_ids = [
  "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns-prod/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net",
  "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns-prod/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net",
  "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns-prod/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io",
  "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns-prod/providers/Microsoft.Network/privateDnsZones/privatelink.westeurope.azurecontainerapps.io"
]

onprem_address_space = ["192.168.0.0/16", "172.16.0.0/12"]

tags = {
  project     = "fastapi-usecase"
  environment = "dev"
  managed_by  = "terraform"
  owner       = "platform-team"
}
