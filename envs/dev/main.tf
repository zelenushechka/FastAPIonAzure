###############################################################################
# FastAPI on Azure — private deployment
#
# Composition order:
#   1. random suffix (for globally-unique names)
#   2. networking module (RG, VNet, subnets, NSGs, peering, DNS links)
#   3. user-assigned managed identity (created here so other modules can grant
#      it least-privilege roles BEFORE the Container App exists)
#   4. key_vault module      → grants "Key Vault Secrets User" to the MI
#   5. storage module        → grants "Storage Blob Data Contributor" to the MI
#   6. container_registry    → grants "AcrPull" to the MI
#   7. container_app module  → uses the MI to pull images and read secrets
###############################################################################

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

locals {
  suffix               = random_string.suffix.result
  storage_account_name = "${var.storage_account_name_prefix}${local.suffix}"
  key_vault_name       = "${var.key_vault_name_prefix}-${local.suffix}"
  acr_name             = "${var.acr_name_prefix}${local.suffix}"
}

###############################################################################
# 2. Networking
###############################################################################
module "networking" {
  source = "../../modules/networking"

  resource_group_name         = var.resource_group_name
  location                    = var.location
  tags                        = var.tags
  hub_vnet_id                 = var.hub_vnet_id
  hub_vnet_name               = var.hub_vnet_name
  hub_resource_group_name     = var.hub_resource_group_name
  hub_dns_resource_group_name = var.hub_dns_resource_group_name
  hub_private_dns_zone_ids    = var.hub_private_dns_zone_ids
  onprem_address_space        = var.onprem_address_space
}

###############################################################################
# 3. User-assigned managed identity for the FastAPI app
###############################################################################
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.app_name}-${var.environment}"
  resource_group_name = module.networking.resource_group_name
  location            = module.networking.location
  tags                = var.tags
}

###############################################################################
# 4. Key Vault (grants Secrets User to the app MI)
###############################################################################
module "key_vault" {
  source = "../../modules/key_vault"

  resource_group_name         = module.networking.resource_group_name
  location                    = module.networking.location
  key_vault_name              = local.key_vault_name
  private_endpoints_subnet_id = module.networking.private_endpoints_subnet_id
  app_principal_id            = azurerm_user_assigned_identity.app.principal_id
  tags                        = var.tags
}

###############################################################################
# 5. Storage Account (grants Blob Data Contributor to the app MI)
###############################################################################
module "storage" {
  source = "../../modules/storage"

  resource_group_name         = module.networking.resource_group_name
  location                    = module.networking.location
  storage_account_name        = local.storage_account_name
  private_endpoints_subnet_id = module.networking.private_endpoints_subnet_id
  app_principal_id            = azurerm_user_assigned_identity.app.principal_id
  tags                        = var.tags
}

###############################################################################
# 6. Azure Container Registry (grants AcrPull to the app MI)
###############################################################################
module "acr" {
  source = "../../modules/container_registry"

  resource_group_name         = module.networking.resource_group_name
  location                    = module.networking.location
  acr_name                    = local.acr_name
  private_endpoints_subnet_id = module.networking.private_endpoints_subnet_id
  app_principal_id            = azurerm_user_assigned_identity.app.principal_id
  tags                        = var.tags
}

###############################################################################
# 7. Container App
#    depends_on ensures role assignments + private endpoints are in place
#    before the app starts, otherwise the first revision fails to pull/auth.
###############################################################################
module "container_app" {
  source = "../../modules/container_app"

  resource_group_name              = module.networking.resource_group_name
  location                         = module.networking.location
  app_name                         = "${var.app_name}-${var.environment}"
  container_apps_subnet_id         = module.networking.container_apps_subnet_id
  user_assigned_identity_id        = azurerm_user_assigned_identity.app.id
  user_assigned_identity_client_id = azurerm_user_assigned_identity.app.client_id
  acr_login_server                 = module.acr.login_server
  storage_account_name             = module.storage.storage_account_name
  storage_container_name           = module.storage.container_name
  key_vault_uri                    = module.key_vault.key_vault_uri
  tags                             = var.tags

  # Initial image — application CD pipeline rolls forward from there.
  container_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

  depends_on = [
    module.key_vault,
    module.storage,
    module.acr,
  ]
}
