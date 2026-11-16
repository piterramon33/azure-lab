output "web_url" {
  description = "Página de la capa web con las pruebas de conectividad."
  value       = "http://${azurerm_public_ip.web.ip_address}"
}

output "web_api_url" {
  description = "Las mismas pruebas en JSON."
  value       = "http://${azurerm_public_ip.web.ip_address}/api"
}

output "db_private_ip" {
  description = "IP privada de la VM de la capa de datos."
  value       = local.db_ip
}

output "resource_group" {
  description = "Grupo de recursos que contiene todo el proyecto."
  value       = azurerm_resource_group.this.name
}

output "bastion_name" {
  description = "Nombre del host de Azure Bastion."
  value       = azurerm_bastion_host.this.name
}

output "admin_username" {
  description = "Usuario para entrar a las VM por Bastion."
  value       = var.admin_username
}

output "ssh_private_key" {
  description = "Clave privada para entrar a las VM por Bastion."
  value       = tls_private_key.admin.private_key_openssh
  sensitive   = true
}
