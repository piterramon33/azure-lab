# Pruebas del diseño con un proveedor de Entra ID simulado.
# No se conectan a ningún directorio ni crean nada.

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
      client_id = "00000000-0000-0000-0000-000000000003"
    }
  }
}

run "modelo_de_acceso_por_grupos" {
  command = plan

  assert {
    condition     = toset(keys(azuread_group.this)) == toset(["platform-admins", "developers", "readers", "deployers"])
    error_message = "Deben existir los cuatro grupos del modelo de acceso."
  }

  assert {
    condition     = alltrue([for g in azuread_group.this : g.security_enabled == true])
    error_message = "Todos los grupos deben ser grupos de seguridad."
  }

  assert {
    condition     = alltrue([for g in azuread_group.this : length(g.owners) > 0])
    error_message = "Ningún grupo debe quedar sin propietario."
  }
}

run "github_entra_sin_secretos" {
  command = plan

  assert {
    condition     = azuread_application_federated_identity_credential.github_branch.issuer == "https://token.actions.githubusercontent.com"
    error_message = "El emisor de la credencial federada debe ser GitHub Actions."
  }

  assert {
    condition     = azuread_application_federated_identity_credential.github_branch.subject == "repo:piterramon33/azure-lab:ref:refs/heads/main"
    error_message = "La credencial solo debe valer para la rama main de este repositorio."
  }

  assert {
    condition     = azuread_application_federated_identity_credential.github_branch.audiences == tolist(["api://AzureADTokenExchange"])
    error_message = "La audiencia debe ser la de intercambio de tokens de Entra ID."
  }

  assert {
    condition     = azuread_application.github.sign_in_audience == "AzureADMyOrg"
    error_message = "La aplicación solo debe aceptar identidades de este directorio."
  }
}

run "pim_desactivado_por_defecto" {
  command = plan

  assert {
    condition     = length(azuread_directory_role_eligibility_schedule_request.privileged) == 0
    error_message = "PIM exige licencia P2 y no debe crearse por defecto."
  }

  assert {
    condition     = length(azuread_group.privileged) == 0
    error_message = "El grupo con roles exige licencia P1 y no debe crearse por defecto."
  }
}

run "pim_activado_usa_elegibilidad_no_asignacion_permanente" {
  command = plan

  variables {
    enable_pim = true
  }

  assert {
    condition     = length(azuread_directory_role_eligibility_schedule_request.privileged) == 1
    error_message = "Con PIM activado debe crearse la asignación elegible."
  }

  assert {
    condition     = azuread_group.privileged[0].assignable_to_role == true
    error_message = "El grupo privilegiado debe poder recibir roles del directorio."
  }

  assert {
    condition     = azuread_directory_role_eligibility_schedule_request.privileged[0].directory_scope_id == "/"
    error_message = "La elegibilidad debe aplicarse a todo el directorio."
  }
}

run "rechaza_repositorio_mal_escrito" {
  command = plan

  variables {
    github_repository = "solo-el-nombre"
  }

  expect_failures = [
    var.github_repository,
  ]
}
