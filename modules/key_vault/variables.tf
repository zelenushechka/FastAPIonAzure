variable "resource_group_name" {
  description = "Resource group for the key vault."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "key_vault_name" {
  description = "Globally-unique key vault name (3-24 chars, alphanumeric + hyphens)."
  type        = string
}

variable "private_endpoints_subnet_id" {
  description = "Subnet ID where the Key Vault Private Endpoint NIC is placed."
  type        = string
}

variable "app_principal_id" {
  description = "Object ID of the principal (managed identity) that should read secrets."
  type        = string
}

variable "create_demo_secret" {
  description = "Whether to create a placeholder secret for demonstration."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
