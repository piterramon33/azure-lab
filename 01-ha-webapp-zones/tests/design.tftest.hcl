# Pruebas del diseño con un proveedor de Azure simulado.
# No necesitan suscripción ni credenciales y no crean nada: comprueban que
# el plan que saldría de este código cumple lo que el proyecto promete.

mock_provider "azurerm" {}

run "reparto_entre_tres_zonas" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.web.zones == toset(["1", "2", "3"])
    error_message = "El conjunto de escalado debe repartirse entre las zonas 1, 2 y 3."
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.web.zone_balance == true
    error_message = "El reparto entre zonas debe ser estricto (zone_balance)."
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.web.instances >= length(var.zones)
    error_message = "Debe haber al menos una instancia por zona."
  }

  assert {
    condition     = azurerm_public_ip.lb.sku == "Standard" && azurerm_public_ip.lb.zones == toset(["1", "2", "3"])
    error_message = "La IP pública debe ser Standard y redundante entre las tres zonas."
  }

  assert {
    condition     = azurerm_lb.this.sku == "Standard"
    error_message = "Solo el balanceador Standard admite zonas de disponibilidad."
  }
}

run "solo_entra_trafico_web" {
  command = plan

  assert {
    condition = alltrue([
      for r in azurerm_network_security_group.web.security_rule :
      r.destination_port_range == "8080"
      if r.direction == "Inbound" && r.access == "Allow"
    ])
    error_message = "El NSG solo debe permitir la entrada al puerto de la aplicación; SSH no se expone."
  }

  assert {
    condition = anytrue([
      for r in azurerm_network_security_group.web.security_rule :
      r.direction == "Inbound" && r.access == "Allow" &&
      r.destination_port_range == "8080" && r.source_address_prefix == "Internet"
    ])
    error_message = "Debe existir la regla que deja entrar el tráfico web desde Internet."
  }

  assert {
    condition     = azurerm_lb_rule.http.frontend_port == 80 && azurerm_lb_rule.http.backend_port == 8080
    error_message = "El balanceador debe publicar el puerto 80 y enviar al 8080 de las instancias."
  }
}

run "sonda_y_reparacion_automatica" {
  command = plan

  assert {
    condition     = azurerm_lb_probe.http.protocol == "Http" && azurerm_lb_probe.http.request_path == "/health"
    error_message = "La sonda debe comprobar /health por HTTP."
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.web.upgrade_mode == "Rolling"
    error_message = "Las actualizaciones deben ser graduales para no tumbar todas las zonas a la vez."
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.web.automatic_instance_repair[0].enabled == true
    error_message = "La reparación automática de instancias debe estar activada."
  }
}

run "arranque_valido" {
  command = plan

  assert {
    condition     = can(yamldecode(file("${path.module}/cloud-init.yaml")).write_files)
    error_message = "cloud-init.yaml debe ser YAML válido con una sección write_files."
  }
}

run "rechaza_una_sola_zona" {
  command = plan

  variables {
    zones = ["1"]
  }

  expect_failures = [
    var.zones,
  ]
}

run "rechaza_prefijo_invalido" {
  command = plan

  variables {
    prefix = "Mi-App"
  }

  expect_failures = [
    var.prefix,
  ]
}
