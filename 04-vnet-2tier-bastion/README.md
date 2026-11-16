# 04 · Red de 2 capas con NSG y Bastion

Una red virtual con una capa web pública y una capa de datos privada. Cada
capa tiene su propio grupo de seguridad de red (NSG), y la administración de
las máquinas se hace solo a través de Azure Bastion, sin abrir SSH a Internet.

## Qué se crea

| Recurso | Para qué |
|---|---|
| Grupo de recursos `rg-twotier` | Contiene todo; borrarlo lo elimina todo |
| Red virtual `10.20.0.0/16` | Tres subredes: web, datos y Bastion |
| NSG de la capa web | Entra HTTP desde Internet y SSH solo desde Bastion |
| NSG de la capa de datos | Entra el puerto 5432 solo desde la capa web y SSH solo desde Bastion; sin salida a Internet |
| VM web con IP pública | Sirve una página que prueba las reglas en vivo |
| VM de datos sin IP pública | Escucha en 5432 como sustituto de una base de datos |
| Azure Bastion | Única vía para entrar a las VM |

La VM de datos no tiene salida a Internet, así que no instala PostgreSQL real:
un servicio mínimo escucha en su puerto para poder comprobar la red.

## Reglas de cada NSG

| Capa | Prioridad | Regla | Efecto |
|---|---|---|---|
| Web | 100 | Internet → 80 | Permitir |
| Web | 110 | Bastion → 22 | Permitir |
| Web | 4096 | Resto de la red virtual | Denegar |
| Datos | 100 | Capa web → 5432 | Permitir |
| Datos | 110 | Bastion → 22 | Permitir |
| Datos | 4096 | Resto de la red virtual | Denegar |
| Datos | 4096 (salida) | Hacia Internet | Denegar |

La regla 4096 existe porque Azure, por defecto, permite todo el tráfico dentro
de una red virtual.

## Desplegar

Bastion tarda unos 10 minutos en crearse y se cobra por hora mientras exista.

```bash
az login
```

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
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

## Probar que funciona

1. Abre la página de la capa web (o consulta la versión JSON):

   ```powershell
   curl.exe -s (terraform output -raw web_api_url)
   ```

   Debe decir que el puerto 5432 está abierto y el 22 cerrado: la capa web
   llega a la base de datos pero no puede administrarla.

2. Comprueba que la capa de datos no es accesible desde Internet: no tiene IP
   pública, así que no hay dirección a la que conectarse.

3. Entra a una VM por Bastion. Exporta la clave:

   ```powershell
   terraform output -raw ssh_private_key | Out-File -Encoding ascii clave.pem
   ```

   En el portal de Azure abre la VM, elige **Conectar → Bastion**, usuario
   `azureuser` y la clave del archivo `clave.pem`.

## Destruir

```bash
terraform destroy
```

Borra después `clave.pem`.

## Notas

- El estado de Terraform es local y contiene la clave SSH. Está excluido de
  git, igual que `clave.pem`; no los compartas.
- Con `-var bastion_sku=Standard` se puede entrar desde la terminal con
  `az network bastion ssh` en lugar del portal; cuesta más por hora.
- La subred de Bastion no lleva NSG propio: es opcional, y añadirlo exige un
  conjunto fijo de reglas que Azure documenta.
