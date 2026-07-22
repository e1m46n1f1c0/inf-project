#!/bin/bash
set -e

# Asegurarse de correr desde la raíz del orquestador
cd "$(dirname "$0")/.."

# 1. Verificar variables del orquestador en .env
if [ ! -f .env ]; then
    echo "⚠️ No se encontró el archivo .env del orquestador (Docker)."
    exit 1
fi

# Cargar variables del .env
set -o allexport
source .env
set +o allexport

# Determinar nombre del contenedor dinámicamente
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ideasfarm}"
SERVICE_NAME="${SERVICE_NAME:-acl-server}"
APP_ENV="${APP_ENV:-prod}"

if [ "$APP_ENV" = "prod" ]; then
  CONTAINER="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"
else
  CONTAINER="${COMPOSE_PROJECT_NAME}-${APP_ENV}-${SERVICE_NAME}-${APP_ENV}"
fi

echo "🚀 Iniciando instalación y configuración del entorno Infinyti..."
echo "🐳 Contenedor objetivo: $CONTAINER"

# 2. Sincronizar submódulos
echo "🔄 Sincronizando submódulos si aplica..."
if [ -d .git ] || [ -f .git ]; then
    git submodule update --init --recursive || true
fi

# 3. Verificar configuraciones del framework en setup/
if [ ! -f setup/.infinyti ]; then
    echo "⚠️ No se encontró el archivo de configuración del framework en setup/.infinyti."
    if [ -f src/infinyti/.env.example ]; then
        cp src/infinyti/.env.example setup/.infinyti.example
    fi
    echo "❌ Error: Copia setup/.infinyti.example a setup/.infinyti, pon tus datos de base de datos y vuelve a correr el script."
    exit 1
fi

if [ ! -f setup/clients.json ] && [ -f setup/clients.json.example ]; then
    echo "⚠️ No se encontró setup/clients.json. Creando uno vacío a partir del example."
    cp setup/clients.json.example setup/clients.json
fi

# 5. Levantar el contenedor en background (por si no está activo)
echo "🐳 Asegurando que los contenedores de Docker estén activos..."
docker compose up -d

# Esperar un par de segundos para que el contenedor esté listo
sleep 3

# 6. Ejecutar composer install dentro del contenedor
echo "📦 Instalando dependencias con Composer..."
docker exec -i $CONTAINER sh -c "cd /var/www/html && composer install --no-interaction --no-scripts --ignore-platform-req=ext-mongodb"

# 7. Restaurar register.json y app start
echo "⚙️  Restaurando register.json y app start..."
if docker exec -i $CONTAINER [ -d /var/www/html/apps-default/start ]; then
    docker exec -i $CONTAINER sh -c "cp -r /var/www/html/apps-default/start /var/www/html/apps/"
fi

if [ ! -f register.json ]; then
    cat <<EOF > register.json
{
    "acl": "acl-oauth/",
    "geoisys": "geoisys/",
    "start": "start/"
}
EOF
fi

# 8. Ejecutar migraciones
echo "🗄️  Ejecutando migraciones de la base de datos..."
if docker exec -i $CONTAINER [ -f "/var/www/html/infinyti" ]; then
    # Limpiar caché estática antes de operar (crítico para asegurar lectura del .env nuevo)
    echo "♻️  Limpiando caché del framework..."
    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti config:refresh --no-interaction || rm -f boot/kernel_state.php"

    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti db:migrate --no-interaction"

    echo "🔗 Vinculando recursos estáticos (assets)..."
    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti assets:link --no-interaction"
else
    echo "⚠️ No se encontró el CLI infinyti. Saltando migraciones."
fi

# 9. Generar llaves OAuth si no existen
echo "🔑 Generando llaves RSA para OAuth2 (si no existen)..."
if docker exec -i $CONTAINER [ -f "/var/www/html/infinyti" ]; then
    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti acl:oauth-keys --no-interaction"

    echo "🔒 Ajustando permisos y propietario de las llaves de seguridad..."
    docker exec -i $CONTAINER chown www-data:www-data /var/www/html/boot/env/private.key /var/www/html/boot/env/public.key 2>/dev/null || true
    docker exec -i $CONTAINER chmod 600 /var/www/html/boot/env/private.key /var/www/html/boot/env/public.key 2>/dev/null || true
fi

# 10. Configuración de clientes ACL
if docker exec -i $CONTAINER [ -f "/var/www/html/infinyti" ] && [ -f "setup/clients.json" ]; then
    echo "⚙️  Verificando clientes de ACL pre-configurados..."
    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti acl:register-clients --file=/var/www/html/setup/clients.json --no-interaction" 2>/dev/null || true
fi

echo "✨ Configuración completada."
