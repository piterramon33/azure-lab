data "azuread_client_config" "current" {}

locals {
  # Modelo de acceso: los permisos se dan a grupos, nunca a personas sueltas.
  groups = {
    platform-admins = "Administran la plataforma. Su acceso privilegiado se activa bajo demanda."
    developers      = "Despliegan y operan sus propias aplicaciones."
    readers         = "Solo lectura: auditoría y consulta."
    deployers       = "Identidades de automatización (pipelines), no personas."
  }

  github_owner = split("/", var.github_repository)[0]
  github_repo  = split("/", var.github_repository)[1]

  # Identidad exacta que GitHub presenta al pedir el token, con los
  # identificadores numéricos del propietario y del repositorio.
  github_subject = join(":", [
    "repo",
    "${local.github_owner}@${var.github_owner_id}/${local.github_repo}@${var.github_repository_id}",
    "ref",
    "refs/heads/${var.github_branch}",
  ])
}

# ---------------------------------------------------------------------------
# Grupos de seguridad
# ---------------------------------------------------------------------------

resource "azuread_group" "this" {
  for_each = local.groups

  display_name            = "grp-${var.prefix}-${each.key}"
  description             = each.value
  security_enabled        = true
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]
}

# ---------------------------------------------------------------------------
# Identidad para GitHub Actions, sin contraseñas ni secretos
# ---------------------------------------------------------------------------

resource "azuread_application" "github" {
  display_name     = "app-${var.prefix}-github-actions"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Credencial federada (OIDC): GitHub demuestra quién es con un token de corta
# duración que firma él mismo. Solo vale para esta rama de este repositorio,
# y no hay nada que guardar, rotar ni filtrar.
resource "azuread_application_federated_identity_credential" "github_branch" {
  # checkov:skip=CKV_AZURE_249: El analizador aún no reconoce el formato propietario@id/repositorio@id que GitHub emite. El sujeto apunta a un único repositorio y rama, sin comodines, y lo verifica la prueba github_entra_sin_secretos.

  application_id = azuread_application.github.id
  display_name   = "github-${var.github_branch}"
  description    = "GitHub Actions en la rama ${var.github_branch} de ${var.github_repository}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = local.github_subject
}

# La identidad del pipeline entra al modelo por su grupo, como cualquier otra.
resource "azuread_group_member" "github_deployer" {
  group_object_id  = azuread_group.this["deployers"].object_id
  member_object_id = azuread_service_principal.github.object_id
}
