#!/bin/bash
set -e

# Asegurarse de correr desde la raíz del orquestador
cd "$(dirname "$0")/.."

# Cargar variables del .env
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi

# Determinar nombre del contenedor dinámicamente
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ideasfarm}"
SERVICE_NAME="${SERVICE_NAME:-website}"
APP_ENV="${APP_ENV:-prod}"

CONTAINER_NAME="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"

echo "🐳 Contenedor objetivo: $CONTAINER_NAME"

# Ejecutar composer install si existe composer.json en /var/www/html
if docker exec -i "$CONTAINER_NAME" [ -f /var/www/html/composer.json ]; then
  echo "📦 Instalando dependencias con Composer..."
  docker exec -i "$CONTAINER_NAME" sh -c "cd /var/www/html && composer install --no-interaction"
else
  echo "⚠️ No se encontró composer.json en el contenedor."
fi
