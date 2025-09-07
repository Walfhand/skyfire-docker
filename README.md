# League of Warcraft - SkyFire 5.4.8 (Dockerized)

This repository provides a Dockerized setup to build and run Project SkyFire 5.4.8 (World of Warcraft 5.4.8 private server) on Ubuntu 24.04, following the official installation guide.

## Components
- World server (`worldserver`)
- Auth server (`authserver`)
- MySQL 8 database (`db`)
- One-shot DB initializer (`dbtool`)
- One-shot data extractor for maps/vmaps/dbc (`extractor`)

## Prerequisites
- Docker and Docker Compose
- A WoW 5.4.8 client directory (for map/dbc/vmaps extraction)

## Structure
- `Dockerfile`: multi-stage build for SkyFire (builder/runtime + targets: world, auth, extractor, dbtool)
- `docker-compose.yml`: services orchestration
- `scripts/`: entrypoints and utilities
- `data/`: target folder for extracted `dbc`, `db2`, `cameras`, `maps`, `vmaps` (mounted volume)
- `wow_client/`: place your local WoW 5.4.8 client here (read-only mount)
- `db-extra/`: put additional world base SQL and update scripts here
- `.env.example`: sample environment variables

## Quick Start
1. Copy `.env.example` to `.env` and adjust if needed.
2. Build images:
   ```bash
   docker compose build
   ```
3. Start database:
   ```bash
   docker compose up -d db
   ```
4. Initialize database schemas and data (idempotent):
   - Place base world SQL and updates if you have them:
     - Base world SQL files in `db-extra/world-base/`
     - Update SQL files in `db-extra/updates/world/` and `db-extra/updates/char/`
   - Run the init tool:
     ```bash
     docker compose run --rm dbtool
     ```
5. Extract maps/vmaps/dbc (one time):
   - Put your client under `./wow_client` (read-only mount).
   - Run extractor:
     ```bash
     docker compose run --rm extractor
     ```
   - The resulting `dbc`, `db2`, `cameras`, `maps`, and `vmaps` will be in `./data`.
6. Start servers:
   ```bash
   docker compose up -d world auth
   ```

## Ports
- Authserver: `3724/tcp`
- Worldserver: `8085/tcp`

## Configuration
Entry points automatically:
- Copy `.conf.dist` to `.conf` if missing
- Inject DB connection parameters from environment
- Set `DataDir=/data` in `worldserver.conf`

You can further tune `worldserver.conf` and `authserver.conf` by creating a bind mount or editing inside the container.

## Environment Variables
See `.env.example`:
- `DB_ROOT_PASSWORD` (default `root`)
- `DB_DEFAULT_SCHEMA` (default `world`)
- `REALMLIST_ADDRESS` used by `dbtool` to update `auth.realmlist` (default `127.0.0.1`)

## Data and Volumes
- `./data` is mounted to `/data` in `world` and used as `DataDir`.
- `./wow_client` must contain your WoW 5.4.8 game files for extraction.
- `dbdata` named volume persists MySQL data.

## Notes
- This setup follows the official steps (packages, build, DB creation/import, configuration, extraction).
- MySQL 8 is used per Ubuntu 24.04 guidance. If you prefer MariaDB, adjust `docker-compose.yml` accordingly.
- Ensure you have appropriate rights to distribute/use client data.

## Troubleshooting
- If `auth` or `world` can’t connect to DB, check `db` health: `docker compose ps` / `docker logs db`.
- Ensure base world SQL is imported (via `dbtool`) and updates applied.
- Verify `./data` contains `dbc`, `db2`, `cameras`, `maps`, `vmaps`.
- Look at container logs: `docker logs world`, `docker logs auth`.

## References
- Official guide: https://wiki.projectskyfire.org/index.php/Installation_(Ubuntu_24.04_LTS)
- SkyFire repo: https://github.com/ProjectSkyfire/SkyFire_548
