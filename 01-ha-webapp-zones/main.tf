locals {
  app_port = 8080

  tags = merge({
    project = "01-ha-webapp-zones"
    managed = "terraform"
  }, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
}

# El balanceador Standard y su IP pública vienen cerrados por defecto:
# sin esta regla no entra tráfico. No se abre SSH (22) a Internet.
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
    destination_port_range     = tostring(local.app_port)
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# ---------------------------------------------------------------------------
# Balanceador de carga con IP con redundancia de zona
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.prefix}-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = local.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "web"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "http" {
  name                = "http-health"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = local.app_port
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = local.app_port
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id

  # La salida a Internet la da la regla de salida de abajo, no esta regla.
  disable_outbound_snat = true
}

# Las subredes nuevas ya no tienen salida a Internet implícita.
# Esta regla da salida explícita (actualizaciones del sistema) usando la misma IP.
resource "azurerm_lb_outbound_rule" "web" {
  name                     = "outbound"
  loadbalancer_id          = azurerm_lb.this.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.web.id
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = "public"
  }
}

# ---------------------------------------------------------------------------
# Conjunto de escalado repartido entre zonas
# ---------------------------------------------------------------------------

# Azure exige una clave o contraseña para crear VM Linux. Se genera una clave
# que queda solo en el estado de Terraform; el puerto 22 no está expuesto.
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = "vmss-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.vm_size
  instances           = var.instance_count
  tags                = local.tags

  # checkov:skip=CKV_AZURE_97: El cifrado en el host exige registrar la característica EncryptionAtHost en la suscripción; sin ella el despliegue falla. Los discos ya se cifran en reposo por defecto.

  # Reparto estricto: mismo número de instancias en cada zona.
  zones        = var.zones
  zone_balance = true

  admin_username                  = var.admin_username
  disable_password_authentication = true
  custom_data                     = base64encode(file("${path.module}/cloud-init.yaml"))
  overprovision                   = false

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.admin.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web.id]
    }
  }

  # La misma sonda del balanceador decide qué instancia está sana.
  health_probe_id = azurerm_lb_probe.http.id
  upgrade_mode    = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent              = 34
    max_unhealthy_instance_percent          = 34
    max_unhealthy_upgraded_instance_percent = 34
    pause_time_between_batches              = "PT30S"
  }

  # Si una instancia deja de responder, Azure la sustituye sola.
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  # La sonda solo cuenta si una regla del balanceador la usa, y la subred
  # necesita su NSG antes de que arranquen las instancias.
  depends_on = [
    azurerm_lb_rule.http,
    azurerm_lb_outbound_rule.web,
    azurerm_subnet_network_security_group_association.web,
  ]
}
