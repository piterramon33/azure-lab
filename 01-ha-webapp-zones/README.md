# 01 · Aplicación web de alta disponibilidad en 3 zonas

Una aplicación web servida por máquinas virtuales repartidas entre las tres
zonas de disponibilidad de una región, detrás de un balanceador con IP
redundante entre zonas. Si se cae una zona entera, las otras dos siguen
atendiendo.

## Qué se crea

| Recurso | Para qué |
|---|---|
| Grupo de recursos `rg-hazones` | Contiene todo; borrarlo lo elimina todo |
| Red virtual y subred `snet-web` | Red privada de las VM |
| Grupo de seguridad de red | Solo deja entrar HTTP; SSH no está expuesto |
| IP pública Standard (zonas 1, 2, 3) | Punto de entrada que sobrevive a la caída de una zona |
| Balanceador Standard | Reparte el tráfico y sondea `/health` cada 5 s |
| Conjunto de escalado (3 VM) | Una VM por zona, con reparación automática |

Cada VM ejecuta una app mínima que responde con la zona en la que está.

## Requisitos

- Terraform 1.9 o superior y Azure CLI.
- Una suscripción con cuota para 3 vCPU en la región elegida.

## Desplegar

1. Iniciar sesión y fijar la suscripción:

   ```bash
   az login
   ```

   ```powershell
   $env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
   ```

2. Comprobar que el tamaño de VM existe en las tres zonas de la región
   (si la columna de restricciones no está vacía, elige otro tamaño o región):

   ```bash
   az vm list-skus --location eastus2 --size Standard_B1s --zone --output table
   ```

3. Revisar el plan y aplicar:

   ```bash
   terraform init
   ```

   ```bash
   terraform plan -out main.tfplan
   ```

   ```bash
   terraform apply main.tfplan
   ```

Para cambiar región, tamaño o número de instancias, pasa variables:
`terraform plan -var location=westeurope -var vm_size=Standard_B2s`.

## Probar que funciona

Las VM tardan uno o dos minutos en responder después del `apply`.

1. Ver cómo responde cada zona (PowerShell):

   ```powershell
   1..12 | ForEach-Object { curl.exe -s (terraform output -raw api_url) }
   ```

   Deben aparecer las zonas 1, 2 y 3.

2. Simular la caída de una instancia y ver que el servicio sigue:

   ```bash
   az vmss list-instances -g rg-hazones -n vmss-hazones --query "[].{id:instanceId, zona:zones[0]}" -o table
   ```

   ```bash
   az vmss deallocate -g rg-hazones -n vmss-hazones --instance-ids 0
   ```

   Repite el paso 1: ahora solo responden dos zonas y no hay errores.

## Destruir

Las VM y la IP pública cuestan dinero mientras existan:

```bash
terraform destroy
```

## Notas

- El estado de Terraform es local y contiene la clave SSH generada. Está
  excluido de git por `.gitignore`; no lo compartas.
- La variante con App Service (plan Premium con redundancia de zona) es más
  cara y no deja ver las zonas; esta versión con VM las hace visibles.
