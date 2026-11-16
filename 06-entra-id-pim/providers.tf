terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# Se autentica con la sesión de Azure CLI. Como no hace falta suscripción,
# el inicio de sesión es: az login --allow-no-subscriptions --tenant <id>
provider "azuread" {
  # Si se deja en null, el proveedor usa ARM_TENANT_ID o el directorio de la
  # sesión de Azure CLI.
  tenant_id = var.tenant_id
}
