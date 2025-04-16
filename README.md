# Dockerized Odoo

This is a flexible and **streamlined** version of most dockerized Odoo projects that you'll find. It allows you to deploy with two different methods using the same Dockerfile:

- **Standalone**: Odoo's source code and dependencies are fully contained within the Docker image. **This is the default and recommended for production.**
- **Hosted**: Odoo's source code resides on the host machine (in `./src/odoo`) and is mounted into the container. Useful for **development** where you directly modify the core Odoo code.

Dockerdoo is integrated with **VSCode** for fast development and debugging, just install the [Remote Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

## Pre-built Images

Pre-built images for various Odoo versions (`15.0`, `16.0`, `17.0`, `18.0`, `master`) and architectures (`linux/amd64`, `linux/arm64`) are automatically built, tested, and published via GitHub Actions to:

- **GitHub Container Registry**: `ghcr.io/iterativo-git/dockerdoo:<odoo_version>` (e.g., `ghcr.io/iterativo-git/dockerdoo:17.0`)
- **Docker Hub**: `iterativodo/dockerdoo:<odoo_version>`
- **Google Container Registry**: `gcr.io/iterativo/dockerdoo:<odoo_version>`

You can often pull a pre-built image directly (by ensuring `image: iterativodo/dockerdoo:\${ODOO_VERSION}` is set in your compose file and `ODOO_VERSION` is defined in `.env`) instead of building it locally, saving time.

## Quick usage

First, clone the repository:

```shell
git clone git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
```

Next, configure your environment by copying the example `.env.example` to `.env` and adjusting the variables, especially `ODOO_VERSION` and `PSQL_VERSION`.

### Standalone (Default)

This uses the pre-built image or builds one with Odoo source included.

```shell
# Ensure ODOO_VERSION is set in .env
docker-compose build # Optional: only needed if not using pre-built or modifying Dockerfile
docker-compose up -d
```

### Hosted (Development)

This requires cloning the Odoo source code into `./src/odoo`.

```shell
# Clone the desired Odoo version source code
git clone --depth=1 -b 17.0 git@github.com:odoo/odoo.git src/odoo # Example for 17.0

# Ensure ODOO_VERSION is set in .env to match the cloned source
docker-compose -f docker-compose.yml -f hosted.yml build # Build is usually required here
docker-compose -f docker-compose.yml -f hosted.yml up -d
```

## Requirements

- [Docker](https://www.docker.com/products/docker-desktop/) (Desktop or Engine)
- [Docker Compose](https://docs.docker.com/compose/install/)
- Git

## Configuration

Configuration is primarily managed through environment variables and compose file overrides.

### Environment Variables (`.env`)

The `.env` file (copied from `.env.example`) is crucial. Key variables include:

- `ODOO_VERSION`: Specifies the Odoo version (e.g., `17.0`). Must match the desired pre-built image tag or the source code version for hosted setups.
- `PSQL_VERSION`: PostgreSQL version (e.g., `16`).
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials.
- `ADMIN_PASSWORD`: The master admin password for new Odoo databases.
- `PIP_AUTO_INSTALL=1`: Set to `1` to automatically install Python requirements from custom addons on startup.
- `UPGRADE_ODOO=1`: Set to `1` to attempt `odoo -u all` on startup.
- `RUN_TESTS=1`: Set to `1` to run Odoo tests on startup (use `WITHOUT_TEST_TAGS` to exclude specific test tags).
- `ODOO_RC`: Path to the Odoo configuration file inside the container (default: `/etc/odoo/odoo.conf`). The entrypoint script manages this file based on environment variables.

Many other environment variables are available to control Odoo's behavior (timeouts, workers, logging, email, etc.) - see the `Dockerfile` and `resources/entrypoint.sh` for details.

### Build Arguments

You can customize the Docker image build using `--build-arg`:

```shell
docker-compose build --build-arg PYTHON_VERSION=3.11-slim --build-arg ODOO_VERSION=17.0
```

Available arguments (see `Dockerfile`): `PYTHON_VERSION`, `OS_VARIANT`, `ODOO_VERSION`, `WKHTMLTOX_VERSION`, `APP_UID`, `APP_GID`.

### Docker Compose Overrides

Multiple compose files allow different configurations:

- `docker-compose.yml`: Base configuration (Standalone mode).
- `hosted.yml`: Overrides for Hosted mode (mounts `./src/odoo`).
- `dev-standalone.yml`: Standalone mode with development tools (e.g., `--dev=all`, potentially WDB).
- `dev-hosted.yml`: Hosted mode with development tools.
- `test-env.yml`: Configured for running Odoo tests (`--test-enable --stop-after-init`).

Combine them using the `-f` flag:

```shell
# Hosted Development
docker-compose -f docker-compose.yml -f hosted.yml -f dev-hosted.yml up

# Run Tests (Standalone)
docker-compose -f docker-compose.yml -f test-env.yml up
```

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
├── .env.example       # Example environment variables (copy to .env)
├── .env               # Your local environment variables (ignored by git)
├── Dockerfile         # Defines the Odoo image build process
├── docker-compose.yml             # Base compose configuration
├── hosted.yml                     # Override for hosted mode
├── dev-standalone.yml             # Override for standalone development
├── dev-hosted.yml                 # Override for hosted development
├── test-env.yml                   # Override for running tests
└── ...                            # Other files (.gitignore, README.md, etc.)
```

### Extra Addons (`./custom`)

Place your custom Odoo modules inside subdirectories within the `./custom/` folder (e.g., `./custom/my_cool_module/`, `./custom/oca_addons/web/`).

The `entrypoint.sh` script runs `getaddons.py`, which scans the `${ODOO_EXTRA_ADDONS}` path (which defaults to `/mnt/extra-addons`, where `./custom` is mounted in `docker-compose.yml`) for valid module directories (those containing `__manifest__.py` or `__openerp__.py`) and adds them to Odoo's `addons_path` configuration.

### SSH Key Access

The base `docker-compose.yml` mounts your host's `~/.ssh/` directory into `/opt/odoo/.ssh/` inside the container. This allows processes within the container (like pip installing from a private git repository) to use your local SSH keys for authentication.

## Exposed Ports

- `8069`: Odoo HTTP interface
- `8072`: Odoo Longpolling port

## Credits

Mainly based on dockery-odoo work by:

- [David Arnold](https://github.com/blaggacao) ([XOE Solutions](https://xoe.solutions))

Bunch of ideas taken from:

- [Odoo](https://github.com/odoo) ([docker](https://github.com/odoo/docker))
- [OCA](https://github.com/OCA) ([maintainer-quality-tools](https://github.com/OCA/maintainer-quality-tools))
- [Ingeniería ADHOC](https://github.com/jjscarafia) ([docker-odoo-adhoc](https://github.com/ingadhoc/docker-odoo-adhoc))

## WIP

- Swarm / Kubernetes considerations (secrets, etc.)
