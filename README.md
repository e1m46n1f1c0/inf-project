# Guía de Orquestación de Entornos — Infinyti Framework

Este repositorio es una plantilla base (orquestador) diseñada para estructurar, desplegar y administrar aplicaciones basadas en el framework Infinyti. Es compatible con dos tipos de arquitectura de repositorios:

1. **Mono-repositorio (`REPO_TYPE=ONE_REPO`):** Para aplicaciones monolíticas auto-contenidas (ej. un sitio web tradicional).
2. **Multi-repositorio (`REPO_TYPE=MULTI_REPO`):** Para arquitecturas modulares compuestas por un framework base, aplicaciones independientes y plantillas/interfaces.

---

## 🛠 Requisitos Previos

- Docker y Docker Compose
- Acceso SSH configurado en GitLab (u otros repositorios remotos registrados)
- Python 3 (requerido por `deploy.sh` para procesar el archivo YAML de configuración de repositorios)

---

## 🚀 Guía de Configuración Rápida

### Paso 1: Configurar variables de entorno generales
Copia el archivo `.env.example` en la raíz como `.env`:
```bash
cp .env.example .env
```
Abre `.env` y ajusta las siguientes variables según las necesidades de tu proyecto:
* `COMPOSE_PROJECT_NAME`: Nombre base del proyecto Docker (ej: `ideasfarm`).
* `CLIENT_DOMAIN`: Dominio principal (ej: `ideasfarm.local`).
* `APP_ENV`: Entorno (`dev` | `alpha` | `beta` | `prod`).
* `SERVICE_NAME`: Identificación del servicio para Traefik (ej: `website` o `acl-server`).
* `SERVICE_SUBDOMAIN`: Subdominio (vacío si es dominio principal, o ej: `login` para `login.ideasfarm.local`).
* `REPO_TYPE`: Define si es `ONE_REPO` o `MULTI_REPO`.
* `MOUNT_CODE`: `true` para desarrollo (monta el código local mediante volumen), `false` para producción (usa el código copiado en la imagen).

### Paso 2: Configurar el Registro de Repositorios (`repos.yml`)
Copia la plantilla de registro:
```bash
cp setup/repos.yml.example setup/repos.yml
```
Dependiendo del tipo de repositorio definido en `.env`, edita el archivo `setup/repos.yml`:

#### Opción A: Configuración Mono-repo (`REPO_TYPE=ONE_REPO`)
En este modo, solo se requiere definir la sección `framework` apuntando al repositorio monolítico. El código de la aplicación se descargará en la ruta indicada:
```yaml
framework:
  url: git@gitlab.com:ideasfarm/website.git
  branch: main
  path: src/website
```

#### Opción B: Configuración Multi-repo (`REPO_TYPE=MULTI_REPO`)
En este modo, se orquesta el framework motor, las aplicaciones modulares y plantillas:
```yaml
# Framework Base (Motor PHP — siempre requerido)
framework:
  url: git@gitlab.com:alvalab/infinyti.git
  branch: develop
  path: src/infinyti

# Aplicaciones (montadas en src/apps/<nombre>/)
apps:
  acl-oauth:
    url: git@gitlab.com:alvalab/acl-oauth.git
    branch: develop
    path: src/apps/acl-oauth
  # Otras apps...

# Plantillas (montadas en src/templates/<tipo>/<nombre>/)
templates:
  front:
    app-template:
      url: git@gitlab.com:alvalab/app-template.git
      branch: develop
      path: src/templates/front/app-template
```

### Paso 3: Sincronizar e Inicializar Repositorios
Ejecuta el script para clonar o sincronizar los submódulos Git definidos en `setup/repos.yml`:
```bash
./deploy.sh init
```

### Paso 4: Configurar los parámetros del Framework (.infinyti)
Copia la plantilla de configuración del framework:
```bash
cp setup/.infinyti.example setup/.infinyti
```
*Edita `setup/.infinyti` con las credenciales de base de datos, URLs y configuraciones internas del motor de la aplicación.*

### Paso 5: Construir e Iniciar Contenedores
1. **Construir la imagen de Docker (obligatorio en modo producción/no-montado):**
   ```bash
   ./deploy.sh build
   ```
2. **Iniciar el contenedor de la aplicación:**
   ```bash
   ./deploy.sh up
   ```

---

## 📖 Comandos Disponibles (`deploy.sh`)

El script principal `./deploy.sh` expone los siguientes comandos:
* `./deploy.sh init`: Sincroniza y actualiza todos los repositorios según `setup/repos.yml`.
* `./deploy.sh build`: Construye la imagen inmutable de Docker para producción.
* `./deploy.sh up`: Inicia los contenedores de Docker en segundo plano.
* `./deploy.sh down`: Detiene y remueve los contenedores y redes asociadas.
* `./deploy.sh status`: Muestra el estado actual de los contenedores Docker.
