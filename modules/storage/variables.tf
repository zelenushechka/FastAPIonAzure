variable "resource_group_name" {
  description = "Resource group for the storage account."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "storage_account_name" {
  description = "Globally-unique storage account name (3-24 lowercase alphanumerics)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "private_endpoints_subnet_id" {
  description = "Subnet ID where the storage Private Endpoint NIC is placed."
  type        = string
}

variable "app_principal_id" {
  description = "Object ID of the principal (managed identity) that should access blobs."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
