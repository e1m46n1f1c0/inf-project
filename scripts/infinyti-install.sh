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

CONTAINER="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"

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


# =================================================================
# GESTIÓN DE DIRECTORIOS Y PERMISOS (DYNAMIC)
# =================================================================
# Determinar directorio raíz del framework en el host
if [ "${REPO_TYPE:-MULTI_REPO}" = "ONE_REPO" ]; then
    FW_DIR="src"
else
    FW_DIR="src/infinyti"
fi

# Array de directorios a crear y otorgar permisos (Ruta:Permisos)
DIR_PERMISSIONS=(
    "${FW_DIR}/logs:777"
    "${FW_DIR}/temp:777"
    "${FW_DIR}/public/assets:777"
    "${FW_DIR}/public/images:777"
    "${FW_DIR}/public/files:777"
)

echo "📁 Configurando directorios de escritura y permisos..."
for item in "${DIR_PERMISSIONS[@]}"; do
    # Separar ruta y permisos
    DIR_PATH="${item%%:*}"
    PERMS="${item##*:}"

    # 1. Gestión en el Host (si MOUNT_CODE es true)
    if [ "${MOUNT_CODE:-true}" = "true" ]; then
        if [ ! -d "$DIR_PATH" ]; then
            echo "  ➕ Creando directorio local (host): $DIR_PATH"
            mkdir -p "$DIR_PATH" 2>/dev/null || true
        fi
        echo "  🔒 Asignando permisos $PERMS local (host): $DIR_PATH"
        chmod "$PERMS" "$DIR_PATH" 2>/dev/null || true
    fi

    # 2. Gestión dentro del contenedor (Traducción de ruta a /var/www/html)
    RELATIVE_PATH="${DIR_PATH#$FW_DIR/}"
    CONTAINER_PATH="/var/www/html/${RELATIVE_PATH}"

    echo "  🐳 Asegurando directorio dentro del contenedor: $CONTAINER_PATH ($PERMS)"
    docker exec -i $CONTAINER sh -c "
        if [ ! -d \"$CONTAINER_PATH\" ]; then
            mkdir -p \"$CONTAINER_PATH\"
        fi
        chmod \"$PERMS\" \"$CONTAINER_PATH\"
    "
done
# =================================================================
# CONFIANZA DE CERTIFICADOS SSL EN DESARROLLO (MKCERT)
# =================================================================
if docker exec -i $CONTAINER [ -f /etc/ssl/certs/rootCA.pem ]; then
    echo "🛡️  Registrando Root CA de mkcert en la lista de confianza del contenedor..."
    docker exec -i $CONTAINER sh -c "cp /etc/ssl/certs/rootCA.pem /usr/local/share/ca-certificates/rootCA.crt && update-ca-certificates"
fi
# =================================================================



# 6. Ejecutar composer install dentro del contenedor
echo "📦 Instalando dependencias con Composer..."
docker exec -i $CONTAINER sh -c "cd /var/www/html && composer install --no-interaction --no-scripts --ignore-platform-req=ext-mongodb"

# 7. Restaurar register.json y app start
echo "⚙️  Restaurando register.json y app start..."
if docker exec -i $CONTAINER [ -d /var/www/html/apps-default/start ]; then
    docker exec -i $CONTAINER sh -c "cp -r /var/www/html/apps-default/start /var/www/html/apps/"
fi

if [ ! -f setup/register.json ]; then
    cat <<EOF > setup/register.json
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

    # Evitar fallos de duplicados en el seeder de roles si ya fue ejecutado anteriormente
    if [ -f "src/apps/acl-oauth/db/seeds/RolesFront.php" ]; then
        echo "🔧 Aplicando parche de idempotencia a RolesFront.php..."
        python3 -c '
import os
file_path = "src/apps/acl-oauth/db/seeds/RolesFront.php"
if os.path.exists(file_path):
    with open(file_path, "r") as f:
        content = f.read()
    old_str = "$table->insert($data)->saveData();"
    new_str = """foreach ($data as $row) {
            $exists = $this->fetchRow("SELECT 1 FROM acl_roles WHERE id = \x27" . $row[\x27id\x27] . "\x27");
            if (!$exists) {
                $table->insert([$row])->saveData();
            }
        }"""
    if old_str in content:
        with open(file_path, "w") as f:
            f.write(content.replace(old_str, new_str))
'
    fi

    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti db:migrate --no-interaction"

    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti db:seed --no-interaction"

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

# 11. Configuración de tareas programadas (cron)
if docker exec -i $CONTAINER [ -f "/var/www/html/infinyti" ]; then
    echo "⏰ Configurando tareas programadas (cron)..."
    docker exec -i $CONTAINER sh -c "cd /var/www/html && php infinyti setup:cron --no-interaction" 2>/dev/null || true
fi

# 12. Recargar PHP-FPM para limpiar OPcache (cero caída)
if docker exec -i $CONTAINER pgrep -o php-fpm >/dev/null 2>&1; then
    echo "♻️  Recargando PHP-FPM para limpiar OPcache..."
    docker exec -i $CONTAINER sh -c "kill -USR2 \$(pgrep -o php-fpm)"
fi

echo "✨ Configuración completada."
