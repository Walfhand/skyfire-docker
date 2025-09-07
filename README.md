# SkyFire 5.4.8 WoW Server - Docker Setup

A complete Docker-based setup for running a SkyFire World of Warcraft 5.4.8 (Mists of Pandaria) private server.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose v2
- World of Warcraft 5.4.8 client files
- At least 4GB RAM available for the containers

### 1. Prepare WoW Client Files

**IMPORTANT**: You must place your WoW 5.4.8 client files in the `wow_client/` directory at the root of this project.

```bash
# Create the wow_client directory if it doesn't exist
mkdir -p wow_client

# Copy your WoW 5.4.8 client files here
# The directory should contain the 'Data' folder and WoW executable
cp -r /path/to/your/wow/client/* wow_client/
```

The `wow_client/` directory structure should look like:

```
wow_client/
├── Data/
├── World of Warcraft.exe (or WoW.exe)
└── ... (other WoW client files)
```

### 2. Prepare Database Files

The project includes a base database in `db-extra/world-base/`:

- `SFDB_full_548_24.001_2024_09_04_Release.zip` - Extract this file to get the SQL database
- `SFDB_full_548_24.001_2024_09_04_Release.sql` - The extracted SQL file

**To use the included database:**

```bash
cd db-extra/world-base/
unzip SFDB_full_548_24.001_2024_09_04_Release.zip
```

**To use your own database:**
Simply replace the SQL file in `db-extra/world-base/` with your own database dump.

> **Note**: All database patches from the SkyFire repository will be automatically applied during the database initialization process.

### 3. Configure Environment

**All server configuration is centralized in the `.env` file**. All environment variables for the database, server paths, and connection settings are defined there. The default settings should work for most setups:

- **Database**: MariaDB with auto-initialization
- **Realm Address**: `127.0.0.1` (localhost)
- **Ports**: Auth server (3724), World server (8085), Database (3306)
- **All paths and credentials**: Defined in `.env`

You can modify any setting by editing the `.env` file before starting the services.

### 4. Build and Start the Server

```bash
# Build all Docker images
make build

# Start the database
make db

# Initialize the database (run once)
make init-db

# Start auth and world servers
make up
```

**Or start everything at once:**

```bash
make build
make up-all
```

## 📋 Available Commands

| Command           | Description                                     |
| ----------------- | ----------------------------------------------- |
| `make help`       | Show all available commands                     |
| `make build`      | Build all Docker images                         |
| `make db`         | Start database only                             |
| `make init-db`    | Initialize database (run after first `make db`) |
| `make up`         | Start world + auth servers (requires db)        |
| `make up-auth`    | Start database + auth server only               |
| `make up-all`     | Start all services (database + auth + world)    |
| `make ps`         | Show service status                             |
| `make logs`       | View logs from all services                     |
| `make logs-world` | View world server logs                          |
| `make logs-auth`  | View auth server logs                           |
| `make stop`       | Stop services (keep data)                       |
| `make down`       | Stop and remove containers (keep data)          |
| `make clean`      | Complete cleanup (removes all data)             |

## 🔧 Data Extraction

**REQUIRED**: You must manually extract the required data from your WoW client before starting the world server:

```bash
make extract-force
```

This command extracts:

- **DBC/DB2 files** - Game database files
- **Maps** - World geometry data
- **VMaps** - Collision and line-of-sight data
- **Cameras** - Camera path data

> **Note**: Data extraction can take 10-30 minutes depending on your system. The extracted data is stored in the `./data/` directory and persists between container restarts. This step is mandatory and must be completed before the world server can function properly.

## 🗂️ Directory Structure

```
skyfire-docker/
├── data/                    # Extracted WoW data (auto-generated)
├── wow_client/             # WoW 5.4.8 client files (YOU MUST ADD)
├── db-extra/
│   └── world-base/         # Database files
├── logs/                   # Server logs (auto-generated)
├── scripts/                # Container entry scripts
├── .env                    # Environment configuration
├── docker-compose.yml      # Service definitions
├── Dockerfile             # Container build instructions
└── Makefile              # Automation commands
```

## 🔍 Troubleshooting

### Common Issues

**"No realms available"**

- Check that both auth and world servers are running: `make ps`
- Verify realmlist.wtf points to `127.0.0.1`
- Check auth server logs: `make logs-auth`

**"World server down"**

- Ensure data extraction completed successfully
- Check world server logs: `make logs-world`
- Verify WoW client files are properly placed in `wow_client/`

**Database connection errors**

- Wait for database to fully initialize (check `make logs`)
- Ensure `make init-db` was run successfully

### Viewing Logs

```bash
# All services
make logs

# Specific service
make logs-world
make logs-auth

# Database logs
docker logs skyfire-docker-db-1
```

### Fresh Start

If you encounter persistent issues:

```bash
# Complete cleanup and restart
make clean
make build
make up-all
```

## ⚙️ Advanced Configuration

### Environment Variables (.env)

All configuration variables are defined in the `.env` file:

```bash
# Server address (change for external access)
REALMLIST_ADDRESS=127.0.0.1

# Data extraction paths (container paths)
WOW_CLIENT_DIR=/wow_client
DATA_DIR=/data

# SkyFire server paths (container paths)
SKYFIRE_BIN=/usr/local/skyfire-server/bin
SKYFIRE_ETC=/usr/local/skyfire-server/etc
SKYFIRE_CONF=/usr/local/skyfire-server/etc

# SQL paths (container paths)
SQL_BASE_DIR=/opt/skyfire/sql
EXTRA_SQL_DIR=/sql-extra

# Database connection settings
DB_HOST=db
DB_PORT=3306
DB_USER=root
DB_PASS=Abc123Abcd

# Database names
LOGIN_DB=auth
WORLD_DB=world
CHAR_DB=characters
```

### External Access

To allow external connections:

1. Change `REALMLIST_ADDRESS` in `.env` to your server's IP

## 📝 Notes

- **First startup** takes longer due to data extraction
- **Logs** are persisted in `./logs/` directory
- **Database data** persists between restarts
- **MMAPS generation** is disabled by default (optional, takes 4-20+ hours)
- The setup uses **MariaDB** instead of MySQL for better performance

## 🆘 Support

For issues specific to this Docker setup, check the logs and ensure all prerequisites are met. For SkyFire server issues, consult the official SkyFire documentation and community resources.
