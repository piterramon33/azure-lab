# Laboratorio de Azure con Terraform

Diez proyectos de infraestructura en Azure, cada uno en su carpeta y escrito
con Terraform.

## Estado

| # | Proyecto | Código | Pruebas simuladas | Desplegado en Azure |
|---|---|---|---|---|
| 1 | [Web de alta disponibilidad en 3 zonas](01-ha-webapp-zones/README.md) | Sí | Sí | No |
| 2 | Sitio estático seguro (Front Door + GitHub Actions) | No | No | No |
| 3 | Backup y recuperación en una segunda región | No | No | No |
| 4 | [Red de 2 capas con NSG y Bastion](04-vnet-2tier-bastion/README.md) | Sí | Sí | No |
| 5 | Clúster AKS de producción | No | No | No |
| 6 | Identidad y acceso con Entra ID y PIM | No | No | No |
| 7 | Red híbrida hub-and-spoke | No | No | No |
| 8 | Monitoreo y control de costos | No | No | No |
| 9 | Landing zone de Azure | No | No | No |
| 10 | [Pipeline de CI para Terraform](10-terraform-cicd/README.md) | Sí | — | No aplica |

Ningún proyecto se ha desplegado todavía: hace falta una suscripción de Azure.
"Pruebas simuladas" significa que el diseño se comprueba con `terraform test`
y un proveedor de Azure simulado, sin crear recursos.

## Requisitos

- Terraform 1.9 o superior.
- Azure CLI y una suscripción, solo para desplegar.

## Comprobar un proyecto sin Azure

Dentro de la carpeta del proyecto:

```bash
terraform init -backend=false
```

```bash
terraform validate
```

```bash
terraform test
```

## Seguridad

- El estado de Terraform (`*.tfstate`) contiene secretos y está excluido de git.
- No hay credenciales en el repositorio.
