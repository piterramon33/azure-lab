output "url" {
  description = "Dirección pública de la aplicación."
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "api_url" {
  description = "Devuelve en JSON la zona y la instancia que atendió la petición."
  value       = "http://${azurerm_public_ip.lb.ip_address}/api"
}

output "resource_group" {
  description = "Grupo de recursos que contiene todo el proyecto."
  value       = azurerm_resource_group.this.name
}

output "scale_set" {
  description = "Nombre del conjunto de escalado."
  value       = azurerm_linux_virtual_machine_scale_set.web.name
}
