###############################################################################
# Networking module
# - Spoke VNet (10.0.0.0/24) named "vnet-usecase-private-01"
# - Subnets:
#     * snet-containerapps  (delegated to Microsoft.App/environments)
#     * snet-private-endpoints
# - NSGs (default-deny inbound; allow 443 from on-prem CIDR via VPN)
# - Hub<->Spoke VNet peering (bi-directional)
# - Links spoke VNet to central private DNS zones hosted in the hub
###############################################################################

resource "azurerm_resource_group" "spoke" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

###############################################################################
# VNet
###############################################################################
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-usecase-private-01"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = ["10.0.0.0/24"]
  tags                = var.tags
}

###############################################################################
# Subnets
###############################################################################
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-containerapps"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.0.0.0/26"] # 64 addresses, /27 minimum for workload-profile ACA

  delegation {
    name = "containerapps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = ["10.0.0.64/27"] # 32 addresses for PEPs
  private_endpoint_network_policies = "Disabled"
}

###############################################################################
# NSGs
# Default Azure rules already deny inbound from Internet.
# We add explicit allow-443 from on-prem CIDR (arrives via the hub/VPN gateway).
###############################################################################
resource "azurerm_network_security_group" "container_apps" {
  name                = "nsg-snet-containerapps"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-HTTPS-From-OnPrem"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.onprem_address_space
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-snet-private-endpoints"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  # Private Endpoints only need to accept traffic from the VNet itself.
  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "container_apps" {
  subnet_id                 = azurerm_subnet.container_apps.id
  network_security_group_id = azurerm_network_security_group.container_apps.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

###############################################################################
# Hub<->Spoke VNet peering
###############################################################################
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true # use hub's VPN gateway for on-prem connectivity
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke-usecase"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

###############################################################################
# Link spoke VNet to central private DNS zones in the hub
# (Zones are already deployed in hub; record creation is automated upstream.)
###############################################################################
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = toset(var.hub_private_dns_zone_ids)

  name                  = "link-${azurerm_virtual_network.spoke.name}-${md5(each.value)}"
  resource_group_name   = var.hub_dns_resource_group_name
  private_dns_zone_name = element(split("/", each.value), length(split("/", each.value)) - 1)
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}
