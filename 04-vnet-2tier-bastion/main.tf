locals {
  vnet_cidr    = "10.20.0.0/16"
  web_cidr     = "10.20.1.0/24"
  data_cidr    = "10.20.2.0/24"
  bastion_cidr = "10.20.255.0/26"

  db_ip   = cidrhost(local.data_cidr, 10)
  db_port = 5432

  tags = merge({
    project = "04-vnet-2tier-bastion"
    managed = "terraform"
  }, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Red virtual con una subred por capa y la subred de Bastion
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [local.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.web_cidr]
}

# La capa de datos es privada: sin IP pública y sin salida a Internet.
resource "azurerm_subnet" "data" {
  name                            = "snet-data"
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.data_cidr]
  default_outbound_access_enabled = false
}

# Azure exige este nombre exacto y un tamaño mínimo de /26.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.bastion_cidr]
}

# ---------------------------------------------------------------------------
# Grupos de seguridad de red: uno por capa
# ---------------------------------------------------------------------------

# Las reglas por defecto de Azure permiten todo el tráfico dentro de la red
# virtual. La regla 4096 de cada NSG lo cierra, de modo que solo pasa lo que
# las reglas anteriores permiten de forma explícita.

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.prefix}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "allow-http-from-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = local.web_cidr
  }

  security_rule {
    name                       = "allow-ssh-from-bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_cidr
    destination_address_prefix = local.web_cidr
  }

  security_rule {
    name                       = "deny-other-vnet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-${var.prefix}-data"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  # Solo la capa web llega a la base de datos, y solo por su puerto.
  security_rule {
    name                       = "allow-db-from-web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(local.db_port)
    source_address_prefix      = local.web_cidr
    destination_address_prefix = local.data_cidr
  }

  security_rule {
    name                       = "allow-ssh-from-bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_cidr
    destination_address_prefix = local.data_cidr
  }

  security_rule {
    name                       = "deny-other-vnet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

# ---------------------------------------------------------------------------
# Azure Bastion: única vía de administración, sin abrir SSH a Internet
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.prefix}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "this" {
  name                = "bas-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.bastion_sku
  tunneling_enabled   = var.bastion_sku == "Standard"
  tags                = local.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
