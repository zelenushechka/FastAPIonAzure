variable "resource_group_name" {
  type        = string
  description = "Resource group for the Container Apps Environment and App."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "app_name" {
  type        = string
  description = "Short application name (used in resource names)."
}

variable "container_apps_subnet_id" {
  type        = string
  description = "Subnet ID for Container Apps infrastructure (must be delegated)."
}

variable "user_assigned_identity_id" {
  type        = string
  description = "Resource ID of the user-assigned identity attached to the app."
}

variable "user_assigned_identity_client_id" {
  type        = string
  description = "Client ID of the user-assigned identity (for DefaultAzureCredential)."
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server (e.g. myacr.azurecr.io). Used for image pulls."
}

variable "container_image" {
  type        = string
  description = "Fully qualified image reference for initial deployment. Subsequent rollouts are handled by the application CD pipeline."
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name exposed to the app via env var."
}

variable "storage_container_name" {
  type        = string
  description = "Storage container exposed to the app via env var."
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI exposed to the app via env var."
}

variable "key_vault_secret_refs" {
  type = list(object({
    name                = string
    key_vault_secret_id = string
  }))
  description = "Secrets resolved from Key Vault and exposed to the container as env vars."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
