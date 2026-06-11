###############################################################################
# Remote state backend (Azure Blob Storage)
#
# The storage account, container, and resource group below are provisioned
# OUT-OF-BAND in a dedicated "tfstate-rg" management subscription:
#
#   - resource_group_name = tfstate-rg
#   - storage_account_name = sttfstate<tenant>
#   - container_name = tfstate
#
# Authentication happens via OIDC federated credentials from GitHub Actions
# (ARM_USE_OIDC=true). No client secrets are stored anywhere.
#
# Native blob lease locking is used (no extra resource needed for locking).
#
# Override per environment via:
#   terraform init -backend-config=backend-dev.hcl
###############################################################################

terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "envs/dev/terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
