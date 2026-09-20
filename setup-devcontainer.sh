#!/bin/bash

# Leer entorno si existe
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# Calcular nombre de proyecto tal como lo hace deploy.sh
DEPLOY_ENV=${DEPLOY_ENV:-dev}
if [ -z "$DEPLOY_ENV" ] || [ "$DEPLOY_ENV" = "prod" ]; then
  if [[ "$COMPOSE_PROJECT_NAME" == *"-${SERVICE_NAME}"* ]]; then COMPOSE_PROJECT_NAME_ENV="$COMPOSE_PROJECT_NAME"; else COMPOSE_PROJECT_NAME_ENV="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}"; fi
else
  if [[ "$COMPOSE_PROJECT_NAME" == *"-${SERVICE_NAME}-${DEPLOY_ENV}"* ]]; then COMPOSE_PROJECT_NAME_ENV="$COMPOSE_PROJECT_NAME"; else COMPOSE_PROJECT_NAME_ENV="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${DEPLOY_ENV}"; fi
fi

# Calcular red
if [ -z "${INFINYTI_NETWORK:-}" ]; then
  INFINYTI_NETWORK="${CLIENT_DOMAIN//./-}"
fi
INFINYTI_NETWORK="${INFINYTI_NETWORK:-$COMPOSE_PROJECT_NAME}"

# Host
if [ -n "${SERVICE_SUBDOMAIN}" ]; then
  if [ "$DEPLOY_ENV" = "prod" ]; then
    SERVICE_HOST="${SERVICE_SUBDOMAIN}.${CLIENT_DOMAIN}"
  else
    SERVICE_HOST="${DEPLOY_ENV}-${SERVICE_SUBDOMAIN}.${CLIENT_DOMAIN}"
  fi
else
  SERVICE_HOST="${CLIENT_DOMAIN}"
fi

echo -e "▶ Generando archivos DevContainer dinámicamente para: \033[1;33m$COMPOSE_PROJECT_NAME_ENV\033[0m"

mkdir -p .devcontainer

# Generar .env aislado para el devcontainer para forzar el project name y variables
cat <<EOF > .devcontainer/.env
COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME_ENV
CONTAINER_NAME=$COMPOSE_PROJECT_NAME_ENV
DEPLOY_ENV=$DEPLOY_ENV
SERVICE_NAME=$SERVICE_NAME
SERVICE_HOST=$SERVICE_HOST
INFINYTI_NETWORK=$INFINYTI_NETWORK
CERT_RESOLVER=${CERT_RESOLVER:-local-acme}
SSH_HOST=${SSH_HOST:-/home/mavo}
EOF

# Generar un docker-compose.yml proxy que incluya los archivos padre
cat <<EOF > .devcontainer/docker-compose.yml
include:
  - ../docker-compose.yml
  - ../docker-compose.mount.yml
EOF

cat <<EOF > .devcontainer/devcontainer.json
{
    "name": "$COMPOSE_PROJECT_NAME_ENV",
    "dockerComposeFile": "docker-compose.yml",
    "service": "app",
    "workspaceFolder": "/var/www/html",
    "remoteUser": "root",
    "customizations": {
        "vscode": {
            "extensions": [
                "bmewburn.vscode-intelephense-client",
                "esbenp.prettier-vscode",
                "vue.volar",
                "eamodio.gitlens"
            ]
        }
    },
    "features": {
        "ghcr.io/devcontainers/features/common-utils:2": {}
    },
    "forwardPorts": [80],
    "postCreateCommand": "apt-get update && apt-get install -y wget && if [ -d /root/.ssh-host ]; then mkdir -p /root/.ssh/sockets && cp -rn /root/.ssh-host/* /root/.ssh/ 2>/dev/null || true && chmod 700 /root/.ssh /root/.ssh/sockets && chmod 600 /root/.ssh/* 2>/dev/null || true && chown -R root:root /root/.ssh; fi && git config --global --add safe.directory '*' && if [ -f .env ]; then set -a; . .env; set +a; fi && SCRIPT=\${INSTALL_SCRIPT:-infinyti-install.sh} && if [ -f \"scripts/\$SCRIPT\" ]; then chmod +x \"scripts/\$SCRIPT\" && \"./scripts/\$SCRIPT\"; else echo \"Script scripts/\$SCRIPT no encontrado.\"; fi"
}
EOF

echo -e "  \033[0;32m✅ Archivo devcontainer.json generado.\033[0m"
