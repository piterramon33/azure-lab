# Pruebas del diseño con un proveedor de Azure simulado.
# No necesitan suscripción ni credenciales y no crean nada: comprueban que
# las reglas de red que saldrían de este código aíslan las capas como se espera.

mock_provider "azurerm" {}

run "capa_de_datos_privada" {
  command = plan

  assert {
    condition     = azurerm_subnet.data.default_outbound_access_enabled == false
    error_message = "La subred de datos no debe tener salida implícita a Internet."
  }

  assert {
    condition     = azurerm_network_interface.db.ip_configuration[0].public_ip_address_id == null
    error_message = "La VM de datos no debe tener IP pública."
  }

  assert {
    condition = alltrue([
      for r in azurerm_network_security_group.data.security_rule :
      r.source_address_prefix != "Internet" && r.source_address_prefix != "*"
      if r.direction == "Inbound" && r.access == "Allow"
    ])
    error_message = "Ninguna regla debe permitir la entrada a la capa de datos desde Internet."
  }

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.data.security_rule :
      r.direction == "Outbound" && r.access == "Deny" && r.destination_address_prefix == "Internet"
    ])
    error_message = "La capa de datos debe denegar de forma explícita la salida a Internet."
  }
}

run "base_de_datos_solo_desde_la_capa_web" {
  command = plan

  assert {
    condition = alltrue([
      for r in azurerm_network_security_group.data.security_rule :
      r.source_address_prefix == "10.20.1.0/24"
      if r.direction == "Inbound" && r.access == "Allow" && r.destination_port_range == "5432"
    ])
    error_message = "El puerto de la base de datos solo debe abrirse a la subred web."
  }

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.data.security_rule :
      r.direction == "Inbound" && r.access == "Allow" &&
      r.destination_port_range == "5432" && r.source_address_prefix == "10.20.1.0/24"
    ])
    error_message = "Debe existir la regla que abre la base de datos a la subred web."
  }

  assert {
    condition = alltrue([
      for nsg in [azurerm_network_security_group.web, azurerm_network_security_group.data] :
      anytrue([
        for r in nsg.security_rule :
        r.direction == "Inbound" && r.access == "Deny" && r.source_address_prefix == "VirtualNetwork"
      ])
    ])
    error_message = "Cada NSG debe cerrar el resto del tráfico interno de la red virtual."
  }
}

run "ssh_solo_a_traves_de_bastion" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for nsg in [azurerm_network_security_group.web, azurerm_network_security_group.data] : [
        for r in nsg.security_rule :
        r.source_address_prefix == "10.20.255.0/26"
        if r.direction == "Inbound" && r.access == "Allow" && r.destination_port_range == "22"
      ]
    ]))
    error_message = "SSH solo debe permitirse desde la subred de Bastion."
  }

  assert {
    condition = alltrue([
      for nsg in [azurerm_network_security_group.web, azurerm_network_security_group.data] :
      anytrue([
        for r in nsg.security_rule :
        r.direction == "Inbound" && r.access == "Allow" &&
        r.destination_port_range == "22" && r.source_address_prefix == "10.20.255.0/26"
      ])
    ])
    error_message = "Cada capa debe permitir SSH desde la subred de Bastion."
  }
}

run "capa_web_publica" {
  command = plan

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.web.security_rule :
      r.direction == "Inbound" && r.access == "Allow" &&
      r.destination_port_range == "80" && r.source_address_prefix == "Internet"
    ])
    error_message = "La capa web debe aceptar HTTP desde Internet."
  }
}

run "subred_de_bastion_correcta" {
  command = plan

  assert {
    condition     = azurerm_subnet.bastion.name == "AzureBastionSubnet"
    error_message = "Azure exige que la subred se llame AzureBastionSubnet."
  }

  assert {
    condition     = tonumber(split("/", azurerm_subnet.bastion.address_prefixes[0])[1]) <= 26
    error_message = "La subred de Bastion debe ser /26 o mayor."
  }
}

run "arranque_valido" {
  command = plan

  assert {
    condition     = can(yamldecode(file("${path.module}/cloud-init-db.yaml")).write_files)
    error_message = "cloud-init-db.yaml debe ser YAML válido con una sección write_files."
  }

  assert {
    condition = can(yamldecode(templatefile("${path.module}/cloud-init-web.yaml", {
      db_ip   = "10.20.2.10"
      db_port = 5432
    })).write_files)
    error_message = "cloud-init-web.yaml debe ser una plantilla que produzca YAML válido."
  }
}

run "rechaza_sku_de_bastion_no_admitido" {
  command = plan

  variables {
    bastion_sku = "Developer"
  }

  expect_failures = [
    var.bastion_sku,
  ]
}
