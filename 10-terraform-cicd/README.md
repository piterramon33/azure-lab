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
| Análisis de seguridad | `checkov` sobre todo el código | Bloquea |
| Inicio de sesión sin secretos | Que el pipeline entra al directorio de Entra ID con la identidad federada del [proyecto 6](../06-entra-id-pim/README.md) | Bloquea |

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

## Inicio de sesión sin secretos (OIDC)

El último trabajo inicia sesión en el directorio de Entra ID sin ninguna
contraseña guardada. GitHub emite un token de identidad que dura minutos, y
el directorio lo acepta porque el proyecto 6 creó una credencial federada
para la rama `main` de este repositorio.

Necesita dos variables del repositorio, que no son secretos:
`AZURE_CLIENT_ID` (la aplicación) y `AZURE_TENANT_ID` (el directorio). Si no
existen, el trabajo se omite. Solo corre en `main`: la credencial no vale
para otras ramas ni para pull requests.

La identidad no tiene ningún rol, así que hoy solo demuestra que el inicio de
sesión funciona. Con una suscripción, es la misma identidad que usaría el
trabajo de despliegue.

## Añadir un proyecto

Basta con crear una carpeta en la raíz con su `providers.tf`. El pipeline la
encuentra sola; no hay que editar el workflow.

## Qué falta para que sea CI/CD completo

Hoy es integración continua (CI): revisa el código, pero no despliega. La parte
de despliegue necesita una suscripción de Azure:

1. Dar a la identidad de GitHub, que ya existe e inicia sesión, un rol sobre
   la suscripción para que pueda crear recursos.
2. Un backend remoto para el estado de Terraform (una cuenta de almacenamiento).
3. Un trabajo `plan` en cada pull request y un `apply` con aprobación manual
   al fusionar en `main`.

## Avisos de seguridad aceptados

El análisis bloquea el pipeline ante cualquier hallazgo. Los que se aceptan
por diseño llevan un comentario `checkov:skip` con el motivo, junto al recurso:

| Aviso | Recurso | Motivo |
|---|---|---|
| `CKV_AZURE_97` | Conjunto de escalado del proyecto 1 | El cifrado en el host exige registrar una característica en la suscripción |
| `CKV_AZURE_119` | Interfaz de red de la VM web del proyecto 4 | La VM web es el punto de entrada público del laboratorio |
| `CKV_AZURE_160` | NSG de la capa web del proyecto 4 | El laboratorio publica HTTP sin certificado |
| `CKV_AZURE_249` | Credencial federada del proyecto 6 | El analizador no reconoce el formato con identificadores que GitHub emite; el sujeto exacto lo verifica una prueba |
