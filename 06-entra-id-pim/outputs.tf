output "groups" {
  description = "Grupos de seguridad creados."
  value       = { for key, group in azuread_group.this : key => group.display_name }
}

output "github_application_name" {
  description = "Nombre de la aplicación que representa a GitHub Actions."
  value       = azuread_application.github.display_name
}

output "github_client_id" {
  description = "ID de cliente que el pipeline usa para iniciar sesión. No es un secreto."
  value       = azuread_application.github.client_id
}

output "tenant_id" {
  description = "ID del directorio, para configurar el inicio de sesión del pipeline."
  value       = data.azuread_client_config.current.tenant_id
}

output "github_oidc_subject" {
  description = "Identidad exacta de GitHub que este directorio acepta."
  value       = azuread_application_federated_identity_credential.github_branch.subject
}

output "pim_enabled" {
  description = "Indica si se creó el acceso privilegiado bajo demanda."
  value       = var.enable_pim
}
