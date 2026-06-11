variable "resource_group_name" {
  description = "Name of the resource group for the spoke networking resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network."
  type        = string
}

variable "hub_resource_group_name" {
  description = "Resource group name of the hub virtual network."
  type        = string
}

variable "hub_dns_resource_group_name" {
  description = "Resource group hosting central Private DNS zones (in the hub)."
  type        = string
}

variable "hub_private_dns_zone_ids" {
  description = "List of central Private DNS zone resource IDs in the hub to link the spoke VNet to (e.g. privatelink.blob.core.windows.net, privatelink.vaultcore.azure.net, privatelink.azurecr.io)."
  type        = list(string)
}

variable "onprem_address_space" {
  description = "CIDR ranges of the on-prem network reaching Azure via the hub VPN gateway."
  type        = list(string)
}
