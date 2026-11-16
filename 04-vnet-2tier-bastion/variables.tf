variable "subscription_id" {
  description = "ID de la suscripción de Azure. Si es null se usa ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
  default     = "twotier"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.prefix))
    error_message = "Usa de 3 a 12 caracteres: minúsculas y números, empezando por letra."
  }
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus2"
}

variable "vm_size" {
  description = "Tamaño de las dos VM."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Usuario administrador de las VM."
  type        = string
  default     = "azureuser"
}

variable "bastion_sku" {
  description = "SKU de Azure Bastion. Basic basta para conectarse desde el portal; Standard permite además el cliente nativo (az network bastion ssh)."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "Valores admitidos: Basic o Standard."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
