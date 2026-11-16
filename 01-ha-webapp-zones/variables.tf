variable "subscription_id" {
  description = "ID de la suscripción de Azure. Si es null se usa ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
  default     = "hazones"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.prefix))
    error_message = "Usa de 3 a 12 caracteres: minúsculas y números, empezando por letra."
  }
}

variable "location" {
  description = "Región de Azure. Debe tener 3 zonas de disponibilidad."
  type        = string
  default     = "eastus2"
}

variable "zones" {
  description = "Zonas de disponibilidad donde se reparten las instancias."
  type        = list(string)
  default     = ["1", "2", "3"]

  validation {
    condition     = length(var.zones) >= 2
    error_message = "Hacen falta al menos 2 zonas para que haya alta disponibilidad."
  }
}

variable "instance_count" {
  description = "Número de máquinas virtuales. Con 3 zonas, al menos 3 (una por zona)."
  type        = number
  default     = 3

  validation {
    condition     = var.instance_count >= 2
    error_message = "Hacen falta al menos 2 instancias."
  }
}

variable "vm_size" {
  description = "Tamaño de VM. Compruébalo con `az vm list-skus` antes de desplegar: no todos los tamaños existen en todas las zonas."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Usuario administrador de las VM."
  type        = string
  default     = "azureuser"
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
