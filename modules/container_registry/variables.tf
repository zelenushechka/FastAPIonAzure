variable "resource_group_name" {
  type        = string
  description = "Resource group for the registry."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "acr_name" {
  type        = string
  description = "Globally-unique ACR name (5-50 alphanumerics)."
  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 alphanumeric characters."
  }
}

variable "private_endpoints_subnet_id" {
  type        = string
  description = "Subnet for the registry Private Endpoint."
}

variable "app_principal_id" {
  type        = string
  description = "Managed identity object ID that requires AcrPull."
}

variable "tags" {
  type    = map(string)
  default = {}
}
