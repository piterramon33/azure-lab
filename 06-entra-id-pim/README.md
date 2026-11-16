# 06 · Identidad y acceso con Entra ID y PIM

Un modelo de acceso para el directorio de Entra ID: los permisos se dan a
grupos, el pipeline de GitHub entra sin contraseñas, y el acceso de
administración se activa solo cuando hace falta (PIM).

Este proyecto no necesita suscripción de Azure: trabaja sobre el directorio.

## Qué se crea

| Recurso | Para qué | Licencia |
|---|---|---|
| 4 grupos de seguridad | `platform-admins`, `developers`, `readers` y `deployers` | Gratuita |
| Aplicación y entidad de servicio | Representan a GitHub Actions en el directorio | Gratuita |
| Credencial federada (OIDC) | Deja entrar al pipeline sin secretos, solo desde la rama `main` de este repositorio | Gratuita |
| Pertenencia a `deployers` | La identidad del pipeline entra al modelo por su grupo | Gratuita |
| Grupo privilegiado y rol elegible (PIM) | Acceso de administración bajo demanda | P1 y P2 |

No se crean usuarios ni contraseñas: no hay ninguna credencial en el estado
de Terraform.

## PIM está desactivado por defecto

PIM exige licencia Entra ID P2, y los grupos que pueden recibir roles exigen
P1. En un directorio gratuito esos recursos no se pueden desplegar, así que
solo se crean con `-var enable_pim=true`. El diseño está probado con un
proveedor simulado, no contra un directorio real.

Con PIM activado, el grupo privilegiado no tiene el rol de forma permanente:
queda como elegible, y cada miembro lo activa durante un tiempo limitado y
con justificación.

## Desplegar

```bash
az login --allow-no-subscriptions --tenant <id-del-directorio>
```

```bash
terraform init
```

```bash
terraform plan -out main.tfplan
```

```bash
terraform apply main.tfplan
```

Hace falta ser administrador del directorio.

## Probar que funciona

1. Ver los grupos creados:

   ```bash
   az ad group list --filter "startswith(displayName,'grp-lab-')" --query "[].displayName" -o tsv
   ```

2. Ver que la aplicación no tiene contraseñas ni certificados, solo la
   credencial federada:

   ```bash
   az ad app credential list --id $(terraform output -raw github_client_id)
   ```

   ```bash
   az ad app federated-credential list --id $(terraform output -raw github_client_id) --query "[].subject" -o tsv
   ```

   La primera lista debe salir vacía; la segunda debe mostrar la rama `main`
   de este repositorio.

## Destruir

```bash
terraform destroy
```

El estado local de Terraform es el único registro de lo creado; consérvalo
hasta destruir.

## Fuera de alcance

- Asignar roles sobre recursos de Azure (RBAC): necesita una suscripción.
- Acceso condicional: necesita licencia P1.
