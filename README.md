# Dockerized Odoo

This is a flexible and **streamlined** version of most dockerized Odoo projects that you'll find. It allows you to deploy with two different methods using the same Dockerfile:

- **Standalone**: Odoo's source code and dependencies are fully contained within the Docker image. **This is the default and recommended for production.**
- **Hosted**: Odoo's source code resides on the host machine (in `./src/odoo`) and is mounted into the container. Useful for **development** where you directly modify the core Odoo code.

Dockerdoo includes a VS Code Dev Containers setup with the Python and Debugpy extensions and launch configurations for running, debugging, upgrading, and testing Odoo.

## Pre-built Images

The maintained versions are **Odoo 18, 19, and 20**, following the stable releases on the [official nightly site](https://nightly.odoo.com/). GitHub Actions builds and tests each version on native `linux/amd64` and `linux/arm64` runners before publishing to:

- **GitHub Container Registry**: `ghcr.io/iterativo-git/dockerdoo:<odoo_version>` (e.g., `ghcr.io/iterativo-git/dockerdoo:18.0`)
- **Docker Hub**: `iterativodo/dockerdoo:<odoo_version>`

You can often pull a pre-built image directly (by ensuring `image: iterativodo/dockerdoo:\${ODOO_VERSION}` is set in your compose file and `ODOO_VERSION` is defined in `.env`) instead of building it locally, saving time.

## Quick usage

First, clone the repository:

```shell
git clone git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
```

Copy `.env.example` to a private file outside the repository and fill in separate `POSTGRES_PASSWORD`, `POSTGRES_ADMIN_PASSWORD`, and `ADMIN_PASSWORD` values. Pass the complete file to Compose with `--env-file /path/to/private.env`. The tracked `.env` supplies additional runtime defaults; do not commit credentials to it.

### Standalone (Default)

This uses the pre-built image or builds one with Odoo source included.

```shell
docker compose --env-file /path/to/private.env build # Optional if using a pre-built image
docker compose --env-file /path/to/private.env up -d
```

### Hosted (Development)

This requires cloning the Odoo source code into `./src/odoo`.

```shell
# Clone the Odoo version selected in the private environment file
git clone --depth=1 -b 18.0 https://github.com/odoo/odoo.git src/odoo

docker compose --env-file /path/to/private.env -f docker-compose.yml -f hosted.yml build
docker compose --env-file /path/to/private.env -f docker-compose.yml -f hosted.yml up -d
```

## Requirements

- [Docker](https://www.docker.com/products/docker-desktop/) (Desktop or Engine)
- [Docker Compose](https://docs.docker.com/compose/install/)
- Git

## Configuration

Configuration is primarily managed through environment variables and compose file overrides.

### Environment Variables (`.env`)

The tracked `.env` file supplies Odoo runtime options; `.env.example` lists the minimum Compose settings. The three password fields are intentionally blank. Supply separate private values for `POSTGRES_PASSWORD`, `POSTGRES_ADMIN_PASSWORD`, and `ADMIN_PASSWORD` through your process environment or a private file passed with `docker compose --env-file /path/to/private.env`. A private environment file must include the other settings from `.env.example` as well; it replaces the default interpolation file. Do not commit populated credentials. Key variables include:

- `ODOO_VERSION`: Specifies the Odoo version (e.g., `18.0`). Must match the desired pre-built image tag or the source code version for hosted setups.
- `PSQL_VERSION`: PostgreSQL version (e.g., `16`).
- `POSTGRES_DB`: Initial database created by PostgreSQL.
- `POSTGRES_USER`, `POSTGRES_PASSWORD`: Odoo's database login. It can create databases but is not a PostgreSQL superuser.
- `POSTGRES_ADMIN_USER`, `POSTGRES_ADMIN_PASSWORD`: PostgreSQL bootstrap superuser used only when initializing an empty data volume. Compose leaves its password empty in the Odoo container.
- `ADMIN_PASSWORD`: The Odoo master password for creating or restoring databases.
- `LIST_DB`: Defaults to `False`; set it to `True` when local development needs the database selector.
- `PIP_AUTO_INSTALL=1`: Set to `1` to automatically install Python requirements from custom addons on startup.
- `UPGRADE_ODOO=1`: Set to `1` to attempt `odoo -u all` on startup.
- `RUN_TESTS=1`: Set to `1` to run Odoo tests on startup (use `WITHOUT_TEST_TAGS` to exclude specific test tags).
- `ODOO_RC`: Path to the Odoo configuration file inside the container (default: `/etc/odoo/odoo.conf`). The entrypoint script manages this file based on environment variables.

Many other environment variables are available to control Odoo's behavior (timeouts, workers, logging, email, etc.) - see the `Dockerfile` and `resources/entrypoint.sh` for details.

#### Existing PostgreSQL volumes

PostgreSQL runs the role-creation script only when its data directory is empty. An existing volume is not changed automatically; Dockerdoo's database health check stays unhealthy if the configured Odoo login is missing, has the wrong password, or still has elevated privileges.

To move an existing installation, stop its Odoo service and make consistent backups of its databases and matching filestore directories. Start only the new database service under a new Compose project name during restore, for example `docker compose -p dockerdoo-new up -d db`. Restore each database with `POSTGRES_USER` as its owner, then restore the matching filestore. Start the new Odoo service after the old one is stopped because both projects use ports 8069 and 8072. Verify database and attachment access before retiring the old project or volume. Keep the old data until verification is complete; Dockerdoo does not migrate or delete it automatically.

### Build Arguments

You can customize the Docker image build using `--build-arg`:

```shell
docker compose --env-file /path/to/private.env build --build-arg PYTHON_VERSION=3.12-slim --build-arg OS_VARIANT=bookworm
```

Available arguments (see `Dockerfile`): `PYTHON_VERSION`, `OS_VARIANT`, `ODOO_VERSION`, `WKHTMLTOX_VERSION`, `APP_UID`, `APP_GID`.

### Docker Compose Overrides

Multiple compose files allow different configurations:

- `docker-compose.yml`: Base configuration (Standalone mode).
- `hosted.yml`: Overrides for Hosted mode (mounts `./src/odoo`).
- `dev-standalone.yml`: Standalone mode with Odoo asset reload, QWeb, and XML development features.
- `dev-hosted.yml`: Hosted mode with the same development features and mounted Odoo source.
- `test-env.yml`: Configured for running Odoo tests (`--test-enable --stop-after-init`).

Combine them using the `-f` flag:

```shell
# Hosted Development
docker compose --env-file /path/to/private.env -f docker-compose.yml -f hosted.yml -f dev-hosted.yml up

# Standalone Development
docker compose --env-file /path/to/private.env -f docker-compose.yml -f dev-standalone.yml up

# Run Tests (Standalone)
docker compose --env-file /path/to/private.env -f docker-compose.yml -f test-env.yml up
```

For custom add-on development, use the standalone development override with a pre-built image: edits in `./custom` are available immediately without rebuilding Odoo. Use hosted mode when you need to edit Odoo itself, and keep the mounted source version aligned with the image.

The development overrides do not start WDB or enable Werkzeug's interactive debugger. The Dev Containers launch configurations use VS Code's Debugpy extension when you explicitly start a debug session.

### Extra Addons (`./custom`)

Place your custom Odoo modules inside subdirectories within the `./custom/` folder (e.g., `./custom/my_cool_module/`, `./custom/oca_addons/web/`).

The `entrypoint.sh` script runs `/getaddons.py`, which scans `${ODOO_EXTRA_ADDONS}` (default `/mnt/extra-addons`) for valid addon directories and adds them to Odoo's `addons_path` configuration. It creates or updates that setting without duplicating discovered paths on container restart.

### Development: Mounted vs. Built-in Custom Addons

There are two primary ways to handle your custom addons:

1. **Mounted Addons (Recommended for Local Development):**
    - Place your custom addons in the `./custom` directory (or subdirectories within it).
    - Use a development override file like `dev-hosted.yml` or `dev-standalone.yml` which mounts the `./custom` directory to `/mnt/extra-addons` inside the container.
    - Odoo will use the code directly from your host machine.
    - Changes you make locally are immediately reflected in the running container (Odoo might need a restart/update `-u` depending on the change).
    - Since the code resides on your host, the `./custom` directory (or specific modules within it) is typically added to your `.gitignore` file to avoid committing them if they are managed in separate repositories.

2. **Built-in Addons (Recommended for Production Images or Sharing):**
    - If you want to create a self-contained image that includes your custom addons, you need to build a custom Docker image based on the Dockerdoo base image.
    - Create a new `Dockerfile` in your project (or a dedicated build directory).
    - Use the following example as a template, assuming your addons are in a local directory named `./my_addons`:

    ```dockerfile
    # Example Dockerfile to add your custom modules
    ARG ODOO_VERSION=18.0 # Or your desired version
    FROM iterativodo/dockerdoo:${ODOO_VERSION}

    # Set standard environment variable (can be overridden)
    ENV ODOO_EXTRA_ADDONS=/mnt/extra-addons

    # Switch to root for installations
    USER root

    # Copy your custom addons from a local directory (e.g., ./my_addons)
    # Adjust the source path './my_addons' as needed. Odoo automatically discovers
    # modules in subdirectories of paths listed in the addons_path.
    COPY --chown=${ODOO_USER}:${ODOO_USER} ./my_addons ${ODOO_EXTRA_ADDONS}/my_addons

    # Install Python dependencies from requirements.txt files within your copied addons
    # This installs build tools, finds requirements, installs them, then cleans up
    RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
        && find ${ODOO_EXTRA_ADDONS}/my_addons -name 'requirements.txt' -exec pip3 --no-cache-dir install -r {} \; \
        && apt-get purge -y --auto-remove build-essential \
        && rm -rf /var/lib/apt/lists/*

    # Switch back to the default odoo user
    USER ${ODOO_USER}
    ```

    - Build this new Dockerfile: `docker build -t my-custom-odoo:latest .`
    - Update your `docker-compose.yml` (or a production override) to use `image: my-custom-odoo:latest` instead of the standard Dockerdoo image.

### SSH Key Access

The base Compose file does not mount host SSH keys. If a local development workflow needs SSH access to a private repository, add an explicit SSH mount in a private Compose override and remove it when it is no longer needed.

## Exposed Ports

- `8069`: Odoo HTTP interface
- `8072`: Odoo Longpolling port

## Project Structure

```bash
your-project/
├── resources/         # Scripts (entrypoint.sh, getaddons.py) used in the container
├── src/
│   └── odoo/          # Odoo source code (only required for Hosted mode)
├── custom/            # Custom Odoo modules go in subdirectories here
│   ├── my_module_1/
│   └── my_module_2/
├── .github/           # GitHub Actions workflows (CI/CD)
├── .env.example       # Minimum Compose variables; password fields are blank
├── .env               # Tracked Odoo runtime settings; keep private values separate
├── Dockerfile         # Defines the Odoo image build process
├── docker-compose.yml             # Base compose configuration
├── hosted.yml                     # Override for hosted mode
├── dev-standalone.yml             # Override for standalone development
├── dev-hosted.yml                 # Override for hosted development
├── test-env.yml                   # Override for running tests
└── ...                            # Other files (.gitignore, README.md, etc.)
```

## Image checks

CI resolves each maintained Odoo branch once per run, installs dependencies from that same checkout, and tests the loaded image before registry login or publication. Version tags are updated only after all six version/architecture jobs pass. Pull requests run the checks without registry credentials. Older branches and previously published tags are retained outside this matrix.

To run the same check against a local image:

```shell
docker build --build-arg ODOO_VERSION=20.0 -t dockerdoo-local:20.0 .
python3 tests/test_runtime.py --image dockerdoo-local:20.0 --odoo-version 20.0 --native-tests
```

The check uses disposable Compose services and generated credentials. It verifies database permissions, runs Odoo's base suite with the existing entrypoint exclusions, then checks HTTP health, image health, and database restart behavior. It removes its containers and volumes and prints the location of its logs. Browser tests require Chrome and are not covered by this image check.

`ODOO_REF` is an optional Docker build argument for a specific upstream revision; it defaults to `ODOO_VERSION`. Both architectures use the same resolved revision in CI. `HTTP_PORT` and `ODOO_HEALTHCHECK_PATH` control the image health probe, whose default path is `/web/health`.

## Credits

Mainly based on dockery-odoo work by:

- [David Arnold](https://github.com/blaggacao) ([XOE Solutions](https://xoe.solutions))

Bunch of ideas taken from:

- [Odoo](https://github.com/odoo) ([docker](https://github.com/odoo/docker))
- [OCA](https://github.com/OCA) ([maintainer-quality-tools](https://github.com/OCA/maintainer-quality-tools))
- [Ingeniería ADHOC](https://github.com/jjscarafia) ([docker-odoo-adhoc](https://github.com/ingadhoc/docker-odoo-adhoc))

## WIP

- Swarm / Kubernetes considerations (secrets, etc.)
