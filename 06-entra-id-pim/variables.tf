variable "tenant_id" {
  description = "ID del directorio de Entra ID. Si es null se usa ARM_TENANT_ID o la sesión de Azure CLI."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefijo para los nombres de grupos y aplicaciones."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.prefix))
    error_message = "Usa de 2 a 12 caracteres: minúsculas y números, empezando por letra."
  }
}

variable "github_repository" {
  description = "Repositorio de GitHub (propietario/nombre) que podrá iniciar sesión sin secretos."
  type        = string
  default     = "piterramon33/azure-lab"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "El formato debe ser propietario/nombre."
  }
}

variable "github_branch" {
  description = "Rama del repositorio autorizada a iniciar sesión."
  type        = string
  default     = "main"
}

variable "enable_pim" {
  description = "Crea el acceso privilegiado bajo demanda (PIM). Exige licencia Entra ID P2; con el directorio gratuito, el despliegue falla."
  type        = bool
  default     = false
}

variable "pim_role" {
  description = "Rol del directorio que el grupo de administradores puede activar con PIM."
  type        = string
  default     = "User Administrator"
}
