# Azure exige una clave o contraseña para crear VM Linux. Se genera una clave
# que queda en el estado de Terraform y se usa para entrar a través de Bastion.
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------------------------------------------
# Capa web: una VM con IP pública que sirve la página de comprobación
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "web" {
  name                = "pip-${var.prefix}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "web" {
  name                = "nic-${var.prefix}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-${var.prefix}-web"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web.id]
  tags                  = local.tags

  custom_data = base64encode(templatefile("${path.module}/cloud-init-web.yaml", {
    db_ip   = local.db_ip
    db_port = local.db_port
  }))

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.admin.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  depends_on = [azurerm_subnet_network_security_group_association.web]
}

# ---------------------------------------------------------------------------
# Capa de datos: una VM sin IP pública, con IP privada fija
# ---------------------------------------------------------------------------

resource "azurerm_network_interface" "db" {
  name                = "nic-${var.prefix}-db"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.data.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.db_ip
  }
}

resource "azurerm_linux_virtual_machine" "db" {
  name                  = "vm-${var.prefix}-db"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.db.id]
  custom_data           = base64encode(file("${path.module}/cloud-init-db.yaml"))
  tags                  = local.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.admin.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  depends_on = [azurerm_subnet_network_security_group_association.data]
}
