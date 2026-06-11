###############################################################################
# Non-secret inputs. Values committed in terraform.tfvars.
# Sensitive inputs (subscription ID, tenant ID) come from TF_VAR_* env vars
# injected by GitHub Actions via OIDC federation - never committed.
###############################################################################

variable "location" {
  type        = string
  description = "Azure region for the spoke resources."
  default     = "westeurope"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)."
  default     = "dev"
}

variable "app_name" {
  type        = string
  description = "Short application name."
  default     = "fastapi"
}

variable "resource_group_name" {
  type    = string
  default = "rg-usecase-private-dev"
}

###############################################################################
# Hub references — values supplied by the platform team (data-source lookups
# would also work, but variables keep cross-subscription topologies portable).
###############################################################################
variable "hub_vnet_id" {
  type        = string
  description = "Resource ID of the hub VNet."
}

variable "hub_vnet_name" {
  type        = string
  description = "Name of the hub VNet."
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource group name of the hub VNet."
}

variable "hub_dns_resource_group_name" {
  type        = string
  description = "Resource group hosting central Private DNS zones."
}

variable "hub_private_dns_zone_ids" {
  type        = list(string)
  description = "Central Private DNS zone IDs to link the spoke VNet to."
}

variable "onprem_address_space" {
  type        = list(string)
  description = "On-prem CIDRs reaching Azure through the hub VPN gateway."
}

###############################################################################
# Names — must be globally unique. We append a short hash for uniqueness.
###############################################################################
variable "storage_account_name_prefix" {
  type    = string
  default = "stusecase"
}

variable "key_vault_name_prefix" {
  type    = string
  default = "kv-usecase"
}

variable "acr_name_prefix" {
  type    = string
  default = "acrusecase"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "fastapi-usecase"
    managed_by = "terraform"
  }
}
