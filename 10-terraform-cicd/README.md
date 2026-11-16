# 10 · Pipeline de CI para Terraform

Un pipeline de GitHub Actions que revisa todo el código de Terraform del
repositorio en cada cambio, sin necesitar una suscripción de Azure.

El archivo está en [`.github/workflows/terraform-ci.yml`](../.github/workflows/terraform-ci.yml),
porque GitHub solo ejecuta los workflows que están en esa carpeta de la raíz.

## Qué hace

| Trabajo | Qué comprueba | Si falla |
|---|---|---|
| Formato | `terraform fmt -check` en todo el repositorio | Bloquea |
| Buscar proyectos | Lista las carpetas que tienen un `providers.tf` | Bloquea |
| Validar y probar | Por cada proyecto: `init`, `validate` y `terraform test` | Bloquea |
| Análisis de seguridad | `checkov` sobre todo el código | Solo informa |

Se ejecuta en cada push a `main`, en cada pull request y a mano desde la
pestaña Actions.

## Cómo prueba sin Azure

Cada proyecto tiene un archivo `tests/design.tftest.hcl` que usa un proveedor
de Azure simulado (`mock_provider`). Terraform calcula el plan como si fuera a
desplegar, pero sin conectarse a nada, y las pruebas comprueban ese plan: que
las VM se reparten entre tres zonas, que SSH no queda expuesto a Internet, que
la capa de datos no tiene salida, etc.

Para ejecutarlas en local, dentro de la carpeta de un proyecto:

```bash
terraform init -backend=false
```

```bash
terraform test
```

## Añadir un proyecto

Basta con crear una carpeta en la raíz con su `providers.tf`. El pipeline la
encuentra sola; no hay que editar el workflow.

## Qué falta para que sea CI/CD completo

Hoy es integración continua (CI): revisa el código, pero no despliega. La parte
de despliegue necesita una suscripción de Azure:

1. Una identidad para GitHub en Azure con credenciales federadas (OIDC), sin
   guardar contraseñas en el repositorio.
2. Un backend remoto para el estado de Terraform (una cuenta de almacenamiento).
3. Un trabajo `plan` en cada pull request y un `apply` con aprobación manual
   al fusionar en `main`.

## Pendiente

- El análisis de seguridad está en modo informativo (`--soft-fail`). Tras la
  primera ejecución hay que revisar los hallazgos y resolverlos o justificarlos
  antes de hacerlo bloqueante.
