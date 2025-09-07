.PHONY: help build pull up up-all down stop restart ps logs logs-world logs-auth db dbtool init-db extractor extract extract-community world auth clean prune nuke

# Use docker compose v2 syntax
COMPOSE ?= docker compose

## Show this help
help:
	@echo "SkyFire 5.4.8 - Docker automation"
	@echo
	@echo "Targets:"
	@echo "  build        Build all images"
	@echo "  pull         Pull base images"
	@echo "  db           Start database only"
	@echo "  init-db      Run one-shot DB initializer (dbtool)"
	@echo "  extract-linux  Extract dbc/db2/cameras/maps/vmaps using built Linux tools (runs inside world image)"
	@echo "  up           Start world + auth (depends on db)"
	@echo "  up-all       Start db + world + auth"
	@echo "  logs         Tail logs of all services"
	@echo "  logs-world   Tail world logs"
	@echo "  logs-auth    Tail auth logs"
	@echo "  ps           Show compose services status"
	@echo "  stop         Stop services (keep volumes)"
	@echo "  down         Stop and remove services (keep volumes)"
	@echo "  clean        Remove stopped containers + dangling images"
	@echo "  prune        Prune unused data (ask confirm)"
	@echo "  nuke         Down + remove volumes (DB DATA LOST)"

## Build all images
build:
	$(COMPOSE) build

## Pull base images
pull:
	$(COMPOSE) pull

## Start only the database
db:
	$(COMPOSE) up -d db

## Initialize database (idempotent)
init-db: db
	$(COMPOSE) build dbtool
	$(COMPOSE) run --rm dbtool

## Start world + auth (depends on db)
up:
	$(COMPOSE) up -d world auth

up-auth:
	$(COMPOSE) up db auth

## Start db + world + auth
up-all:
	$(COMPOSE) up db world auth

## Show status
ps:
	$(COMPOSE) ps

## Force re-extraction of data (bypasses automatic check)
## Requires: wow_client mounted and images built (make build)
## NOTE: Extraction is now automatic on first world startup, use this only to force re-extraction
extract-force:
	$(COMPOSE) run --rm --entrypoint /bin/bash world -c \
		'rm -rf /data/dbc /data/db2 /data/cameras /data/maps /data/vmaps /data/Buildings && \
		mkdir -p /data/{dbc,db2,cameras,maps,vmaps,Buildings} && \
		cd /wow_client && \
		mkdir -p dbc db2 cameras maps Buildings && \
		chmod 777 dbc db2 cameras maps Buildings && \
		echo "Extracting DBC, DB2, cameras, and maps..." && \
		/usr/local/skyfire-server/bin/mapextractor && \
		echo "Extracting VMAP data..." && \
		/usr/local/skyfire-server/bin/vmap4extractor && \
		echo "Moving extracted data to /data..." && \
		cp -r dbc/* /data/dbc/ 2>/dev/null || true && \
		cp -r db2/* /data/db2/ 2>/dev/null || true && \
		cp -r cameras/* /data/cameras/ 2>/dev/null || true && \
		cp -r maps/* /data/maps/ 2>/dev/null || true && \
		cp -r Buildings/* /data/Buildings/ 2>/dev/null || true && \
		echo "Assembling VMAP files in /data..." && \
		cd /data && \
		/usr/local/skyfire-server/bin/vmap4assembler Buildings vmaps && \
		cd /wow_client && \
		rm -rf dbc db2 cameras maps Buildings && \
		echo "Extraction completed successfully!"'

## Tail logs of all services
logs:
	$(COMPOSE) logs -f --tail=200

## Tail world logs
logs-world:
	$(COMPOSE) logs -f --tail=200 world

## Tail auth logs
logs-auth:
	$(COMPOSE) logs -f --tail=200 auth

## Stop services (keep volumes)
stop:
	$(COMPOSE) stop

## Stop and remove containers (keep volumes)
down:
	$(COMPOSE) down

## Complete cleanup: stop, remove containers and volumes (fresh start)
clean:
	$(COMPOSE) down -v
	docker system prune -f

## Aggressive prune of docker unused data (asks for confirm)
prune:
	docker system prune
