# Acceso privilegiado bajo demanda (PIM).
#
# Desactivado por defecto: PIM exige licencia Entra ID P2 y los grupos que
# pueden recibir roles exigen P1. En un directorio gratuito el despliegue de
# estos recursos falla, así que solo se crean con enable_pim = true.

# Grupo al que se le puede asignar un rol del directorio.
resource "azuread_group" "privileged" {
  count = var.enable_pim ? 1 : 0

  display_name            = "grp-${var.prefix}-privileged-admins"
  description             = "Pueden activar el rol ${var.pim_role} durante un tiempo limitado."
  security_enabled        = true
  assignable_to_role      = true
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]
}

resource "azuread_directory_role" "pim_target" {
  count = var.enable_pim ? 1 : 0

  display_name = var.pim_role
}

# El grupo no tiene el rol de forma permanente: queda como elegible, y cada
# miembro lo activa cuando lo necesita, con justificación.
resource "azuread_directory_role_eligibility_schedule_request" "privileged" {
  count = var.enable_pim ? 1 : 0

  role_definition_id = azuread_directory_role.pim_target[0].template_id
  principal_id       = azuread_group.privileged[0].object_id
  directory_scope_id = "/"
  justification      = "Acceso de administración bajo demanda para el grupo privilegiado."
}
