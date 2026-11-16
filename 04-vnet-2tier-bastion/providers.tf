terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Si se deja en null, el proveedor usa la variable de entorno ARM_SUBSCRIPTION_ID.
  subscription_id = var.subscription_id

  # Registrar solo los proveedores de recursos que este proyecto usa.
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Compute", "Microsoft.Network"]
}
