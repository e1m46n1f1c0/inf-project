.PHONY: help setup init up down build status ps logs restart refresh sh install deploy update-submodules

help:
	@echo ""
	@echo "================================================================="
	@echo "   Infinyti Framework Website - Comandos Disponibles             "
	@echo "================================================================="
	@echo "Ciclo de Vida & Despliegue:"
	@echo "  make setup                Copia plantillas (.env, repos.yml, .infinyti)"
	@echo "  make init                 Sincroniza y clona los submódulos Git"
	@echo "  make up                   Levanta el entorno según .env"
	@echo "  make down                 Detiene y remueve el contenedor"
	@echo "  make build                Construye la imagen Docker inmutable"
	@echo "  make deploy               Flujo de despliegue automático completo"
	@echo "  make restart              Reinicia el entorno"
	@echo "  make ps / make status     Muestra el estado del contenedor"
	@echo "  make logs                 Sigue los logs del contenedor en tiempo real"
	@echo ""
	@echo "Herramientas de Desarrollo:"
	@echo "  make refresh              Ejecuta 'php infinyti config:build'"
	@echo "  make install              Ejecuta el script de instalación configurado"
	@echo "  make update-submodules    Actualiza los submódulos registrados"
	@echo "  make sh                   Abre una shell interactiva en el contenedor"
	@echo "================================================================="
	@echo ""

setup:
	@echo "Configurando entorno inicial de website..."
	@[ -f .env ] && echo "  ✓ El archivo .env ya existe." || (cp .env.example .env && echo "  ✓ .env creado desde .env.example")
	@[ -f setup/repos.yml ] && echo "  ✓ setup/repos.yml ya existe." || (cp setup/repos.yml.example setup/repos.yml && echo "  ✓ setup/repos.yml creado")
	@[ -f setup/.infinyti ] && echo "  ✓ setup/.infinyti ya existe." || (cp setup/.infinyti.example setup/.infinyti && echo "  ✓ setup/.infinyti creado")

init:
	@bash ./deploy.sh init

up:
	@bash ./deploy.sh up

down:
	@bash ./deploy.sh down

build:
	@bash ./deploy.sh build

deploy:
	@echo "🚀 Iniciando despliegue automático..."
	@bash ./deploy.sh init
	@if [ -f .env ] && grep -q "MOUNT_CODE=false" .env; then \
		echo "📦 Entorno de producción detectado (MOUNT_CODE=false). Construyendo imagen..."; \
		bash ./deploy.sh build; \
	else \
		echo "📂 Entorno de desarrollo detectado (MOUNT_CODE=true). Omitiendo construcción de imagen..."; \
	fi
	@bash ./deploy.sh up
	@echo "✅ Despliegue completado con éxito!"

update-submodules:
	@bash ./scripts/update-submodules.sh

status:
	@bash ./deploy.sh status

ps:
	@bash ./deploy.sh status

logs:
	@if [ -f .env ]; then \
		set -o allexport; source .env; set +o allexport; \
		CONTAINER="$${COMPOSE_PROJECT_NAME:-ideasfarm}-$${SERVICE_NAME:-website}-$${APP_ENV:-prod}"; \
		docker logs -f "$$CONTAINER"; \
	fi

restart:
	@make down
	@make up

refresh:
	@bash ./deploy.sh refresh

install:
	@bash ./deploy.sh install

sh:
	@if [ -f .env ]; then \
		set -o allexport; source .env; set +o allexport; \
		CONTAINER="$${COMPOSE_PROJECT_NAME:-ideasfarm}-$${SERVICE_NAME:-website}-$${APP_ENV:-prod}"; \
		docker exec -it "$$CONTAINER" sh; \
	fi
