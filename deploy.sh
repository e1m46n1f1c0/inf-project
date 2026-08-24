#!/usr/bin/env bash
# =============================================================
# deploy.sh — Orquestador de Entorno Único Infinyti Framework
# Uso: ./deploy.sh [up|down|status|init]
# =============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

cd "$(dirname "$0")"

if [ ! -f ".env" ]; then
  echo -e "${RED}❌ No se encontró .env${NC}"
  echo -e "   Copia .env.example a .env y configúralo."
  exit 1
fi

set -o allexport
source .env
set +o allexport

ACTION="${1:-up}"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ideasfarm}"
CLIENT_DOMAIN="${CLIENT_DOMAIN:-ideasfarm.local}"
APP_ENV="${APP_ENV:-prod}"
SERVICE_NAME="${SERVICE_NAME-acl-server}"
SERVICE_SUBDOMAIN="${SERVICE_SUBDOMAIN-login}"
MOUNT_CODE="${MOUNT_CODE:-true}"

if [ "$APP_ENV" = "prod" ]; then
  COMPOSE_PROJECT_NAME_ENV="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}"
  CONTAINER_NAME="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"
  if [ -n "${SERVICE_SUBDOMAIN}" ]; then
    SERVICE_HOST="${SERVICE_SUBDOMAIN}.${CLIENT_DOMAIN}"
  else
    SERVICE_HOST="${CLIENT_DOMAIN}"
  fi
else
  COMPOSE_PROJECT_NAME_ENV="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"
  CONTAINER_NAME="${COMPOSE_PROJECT_NAME}-${SERVICE_NAME}-${APP_ENV}"
  if [ -n "${SERVICE_SUBDOMAIN}" ]; then
    SERVICE_HOST="${APP_ENV}-${SERVICE_SUBDOMAIN}.${CLIENT_DOMAIN}"
  else
    SERVICE_HOST="${APP_ENV}.${CLIENT_DOMAIN}"
  fi
fi

NETWORK_NAME="private-network-${COMPOSE_PROJECT_NAME}"

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD} Infinyti Framework — Orquestador de Entorno: ${YELLOW}${APP_ENV}${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Proyecto   : ${YELLOW}${COMPOSE_PROJECT_NAME_ENV}${NC}"
echo -e " Host       : ${YELLOW}https://${SERVICE_HOST}${NC}"
echo -e " Contenedor : ${YELLOW}${CONTAINER_NAME}${NC}"
echo -e " Montar local: ${YELLOW}${MOUNT_CODE}${NC}"
echo -e " Acción     : ${YELLOW}${ACTION}${NC}"
echo ""

ensure_network() {
  if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    echo -e "  ${CYAN}🌐 Creando red: ${NETWORK_NAME}${NC}"
    docker network create "$NETWORK_NAME"
  else
    echo -e "  ${GREEN}✓ Red existente: ${NETWORK_NAME}${NC}"
  fi
}

env_init() {
  local REPOS_FILE="setup/repos.yml"
  if [ ! -f "$REPOS_FILE" ]; then
    echo -e "${YELLOW}⚠️  No se encontró ${REPOS_FILE}${NC}"
    echo -e "   Copia setup/repos.yml.example a setup/repos.yml y configúralo."
    exit 1
  fi

  echo -e "${BOLD}🔄 Sincronizando submódulos desde ${REPOS_FILE}...${NC}"

  python3 -c "
import yaml, os, subprocess, re

with open('$REPOS_FILE', 'r') as f:
    data = yaml.safe_load(f) or {}

valid_paths = set()

def collect_entries(info):
    if not isinstance(info, dict):
        return
    if 'url' in info and 'path' in info:
        valid_paths.add(info['path'].rstrip('/'))
        return
    for k, v in info.items():
        if isinstance(v, dict):
            collect_entries(v)

collect_entries(data)

if os.path.exists('.gitmodules'):
    with open('.gitmodules', 'r') as f:
        content = f.read()
    current_submodules = re.findall(r'\[submodule \"(.*?)\"\]', content)
    for sub in current_submodules:
        sub_path = sub.rstrip('/')
        if sub_path not in valid_paths:
            print(f'🗑️ Removiendo submódulo no configurado: {sub_path}')
            subprocess.run(['git', 'rm', '-f', sub_path], check=False)
            subprocess.run(['rm', '-rf', f'.git/modules/{sub_path}'], check=False)
            subprocess.run(['git', 'config', '-f', '.gitmodules', '--remove-section', f'submodule.{sub}'], check=False)

def process_entry(name, info):
    if not isinstance(info, dict):
        return
    url = info.get('url')
    branch = info.get('branch', 'develop')
    path = info.get('path', '').rstrip('/')
    if not url or not path:
        return

    print(f'\n📌 Submódulo: {name} ({path}) -> rama: {branch}')

    if not os.path.exists('.gitmodules'):
        open('.gitmodules', 'a').close()
        subprocess.run(['git', 'add', '.gitmodules'], check=False)

    if not os.path.exists(path) or not os.path.exists(os.path.join(path, '.git')):
        subprocess.run(['git', 'submodule', 'add', '-f', '-b', branch, url, path], check=False)
    else:
        subprocess.run(['git', 'config', '-f', '.gitmodules', f'submodule.{path}.url', url], check=False)
        subprocess.run(['git', 'config', '-f', '.gitmodules', f'submodule.{path}.branch', branch], check=False)
        subprocess.run(['git', 'submodule', 'sync', '--', path], check=False)

    subprocess.run(['git', 'submodule', 'update', '--init', '--recursive', path], check=False)
    subprocess.run(['git', '-C', path, 'fetch', 'origin'], check=False)
    subprocess.run(['git', '-C', path, 'checkout', branch], check=False)
    subprocess.run(['git', '-C', path, 'pull', 'origin', branch], check=False)

def run_process(data):
    if not isinstance(data, dict):
        return
    for k, v in data.items():
        if isinstance(v, dict):
            if 'url' in v and 'path' in v:
                process_entry(k, v)
            else:
                for k2, v2 in v.items():
                    if isinstance(v2, dict):
                        if 'url' in v2 and 'path' in v2:
                            process_entry(f'{k}/{k2}', v2)
                        else:
                            for k3, v3 in v2.items():
                                if isinstance(v3, dict) and 'url' in v3 and 'path' in v3:
                                    process_entry(f'{k}/{k2}/{k3}', v3)

run_process(data)
"
  echo -e "\n${GREEN}✅ Submódulos sincronizados según repos.yml.${NC}"

  if [ ! -f ".gitmodules" ] || ! grep -q "\[submodule" .gitmodules 2>/dev/null; then
    echo -e "${YELLOW}ℹ️ No se detectaron submódulos registrados.${NC}"
    read -p "¿Deseas crear la carpeta src/ localmente para montar código desde el anfitrión? [s/N]: " create_src </dev/tty
    if [[ "$create_src" =~ ^([sS][iI]|[sS])$ ]]; then
      mkdir -p src
      echo -e "${GREEN}✓ Carpeta src/ creada y lista para montar código local.${NC}"
      python3 -c "import sys; content=open(sys.argv[1]).read(); content=content.replace('MOUNT_CODE=false', 'MOUNT_CODE=true'); open(sys.argv[1], 'w').write(content)" .env
      echo -e "${GREEN}✓ MOUNT_CODE=true configurado en .env.${NC}"
    fi
  fi
}

COMPOSE_FILES=("-f" "docker-compose.yml")
if [ "${MOUNT_CODE:-true}" = "true" ] && [ -f "docker-compose.mount.yml" ]; then
  COMPOSE_FILES+=("-f" "docker-compose.mount.yml")
fi

env_build() {
  echo -e "${BOLD}🔨 Construyendo imagen inmutable para entorno: ${YELLOW}${APP_ENV}${NC}"
  INFINYTI_NETWORK="${COMPOSE_PROJECT_NAME}" \
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" \
  SERVICE_NAME="${SERVICE_NAME}" \
  APP_ENV="$APP_ENV" \
  SERVICE_HOST="$SERVICE_HOST" \
  CONTAINER_NAME="$CONTAINER_NAME" \
  docker compose "${COMPOSE_FILES[@]}" -p "$COMPOSE_PROJECT_NAME_ENV" build
}

env_up() {
  ensure_network "$NETWORK_NAME"

  echo -e "${BOLD}▶ Levantando contenedor: ${CYAN}${CONTAINER_NAME}${NC}"
  if [ "${MOUNT_CODE:-true}" = "true" ]; then
    echo -e "  ${YELLOW}📂 Modo Desarrollo: Montando código local vía volumen.${NC}"
  else
    echo -e "  ${GREEN}🔒 Modo Producción/Inmutable: Usando código dentro de la imagen.${NC}"
  fi

  INFINYTI_NETWORK="${COMPOSE_PROJECT_NAME}" \
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" \
  SERVICE_NAME="${SERVICE_NAME}" \
  APP_ENV="$APP_ENV" \
  SERVICE_HOST="$SERVICE_HOST" \
  CONTAINER_NAME="$CONTAINER_NAME" \
  docker compose "${COMPOSE_FILES[@]}" -p "$COMPOSE_PROJECT_NAME_ENV" up -d

  if [ "${MOUNT_CODE:-true}" != "true" ]; then
    if [ -d "src" ]; then
      echo -e "  ${YELLOW}🗑️  Eliminando directorio src local (MOUNT_CODE=false)...${NC}"
    #   docker run --rm -v "$PWD":/app alpine rm -rf /app/src
    fi
  fi

  env_install

  echo -e "  ${GREEN}✅ Entorno ${APP_ENV} activo en: https://${SERVICE_HOST}${NC}"
}

env_down() {
  echo -e "${BOLD}▶ Deteniendo entorno: ${YELLOW}${APP_ENV}${NC}"
  INFINYTI_NETWORK="${COMPOSE_PROJECT_NAME}" \
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" \
  SERVICE_NAME="${SERVICE_NAME}" \
  APP_ENV="$APP_ENV" \
  CONTAINER_NAME="$CONTAINER_NAME" \
  docker compose "${COMPOSE_FILES[@]}" -p "$COMPOSE_PROJECT_NAME_ENV" down
  echo -e "  ${GREEN}✅ Entorno ${APP_ENV} detenido.${NC}"
}

env_install() {
  INSTALL_SCRIPT="${INSTALL_SCRIPT:-}"
  if [ -n "$INSTALL_SCRIPT" ]; then
    local SCRIPT_PATH="scripts/$INSTALL_SCRIPT"
    if [ -f "$SCRIPT_PATH" ]; then
      echo -e "${BOLD}⚙️  Ejecutando instalación: ${YELLOW}${SCRIPT_PATH}${NC}..."
      chmod +x "$SCRIPT_PATH"
      ./"$SCRIPT_PATH"
    else
      echo -e "${RED}❌ Error: El script '${SCRIPT_PATH}' no existe.${NC}"
      exit 1
    fi
  else
    echo -e "${CYAN}ℹ️  INSTALL_SCRIPT está vacío. No hay tareas de instalación configuradas.${NC}"
  fi
}

env_status() {
  echo -e "${BOLD}📊 Estado del entorno:${NC}"
  docker compose "${COMPOSE_FILES[@]}" -p "$COMPOSE_PROJECT_NAME_ENV" ps
}

env_refresh() {
  echo -e "${BOLD}📊 Refrescando Configuración:${NC}"
  docker exec -i "${CONTAINER_NAME}" php infinyti config:build
}

env_init_ideasfarm() {
  docker exec -i "${COMCONTAINER_NAME}" php infinyti horizon --eval "DB::table('aml_animals_status')->count()"
}

case "$ACTION" in
  up) env_up ;;
  down) env_down ;;
  status) env_status ;;
  build) env_build ;;
  init) env_init ;;
  install) env_install ;;
  refresh) env_refresh ;;
  *)
    echo -e "${RED}❌ Acción desconocida: ${ACTION}${NC}"
    echo "   Uso: ./deploy.sh [up|down|status|build|init|install]"
    exit 1
    ;;
esac


