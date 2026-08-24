# =============================================================
# Makefile — Automatización de Despliegue para Infinyti Framework
# =============================================================

.PHONY: help init build up down status restart deploy update_submodules

help:
	@echo "Uso: make [comando]"
	@echo ""
	@echo "Comandos disponibles:"
	@echo "  init            - Sincroniza e inicializa los submódulos Git."
	@echo "  build           - Construye la imagen Docker (Modo Producción)."
	@echo "  up              - Levanta los contenedores del entorno."
	@echo "  down            - Detiene y remueve los contenedores del entorno."
	@echo "  status          - Muestra el estado del entorno y contenedores."
	@echo "  restart         - Detiene y vuelve a levantar los contenedores."
	@echo "  deploy          - [AUTOMÁTICO] Realiza todo el flujo de despliegue según el entorno."
	@echo "  refresh         - Refresca la cache de configuración de la applicacion"
	@echo "  update_submodules - Actualiza los submódulos Git y pregunta para confirmarlos en Git."

init:
	@git submodule update --init --recursive --force || true
	@./deploy.sh init

build:
	@./deploy.sh build

up:
	@./deploy.sh up

down:
	@./deploy.sh down

status:
	@./deploy.sh status

restart: down up

deploy:
	@echo "🚀 Iniciando despliegue automático..."
	@git submodule update --init --recursive --force || true
	@./deploy.sh init
	@if grep -q "MOUNT_CODE=false" .env; then \
		echo "📦 Entorno de producción detectado (MOUNT_CODE=false). Construyendo imagen..."; \
		./deploy.sh build; \
	else \
		echo "📂 Entorno de desarrollo detectado (MOUNT_CODE=true). Omitiendo construcción de imagen..."; \
	fi
	@./deploy.sh up
	@echo "✅ Despliegue completado con éxito!"

refresh:
	@./deploy.sh refresh

update_submodules:
	@./scripts/update-submodules.sh
