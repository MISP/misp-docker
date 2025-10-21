.DEFAULT_GOAL := help

.PHONY: help build build-core build-modules build-guard build-slim bake up down logs shellcheck clean prune

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build targets:"
	@echo "  build          Build all images via docker compose"
	@echo "  build-core     Build misp-core only"
	@echo "  build-modules  Build misp-modules only"
	@echo "  build-guard    Build misp-guard only"
	@echo "  build-slim     Build all slim variant images"
	@echo "  bake           Build all images via docker buildx bake"
	@echo ""
	@echo "Runtime targets:"
	@echo "  up             Start all services in background"
	@echo "  down           Stop all services"
	@echo "  logs           Tail logs from all services"
	@echo ""
	@echo "Utility targets:"
	@echo "  shellcheck     Lint shell scripts"
	@echo "  clean          Stop services and remove volumes"
	@echo "  prune          Docker system prune (cleanup)"

build:
	docker compose build

build-core:
	docker compose build misp-core

build-modules:
	docker compose build misp-modules

build-guard:
	docker compose build misp-guard

build-slim:
	docker compose build --build-arg CORE_FLAVOR=slim --build-arg MODULES_FLAVOR=slim

bake:
	docker buildx bake

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

shellcheck:
	shellcheck core/files/*.sh core/files/kubernetes/*.sh guard/files/*.sh

clean:
	docker compose down -v --remove-orphans

prune:
	docker system prune -af --volumes
