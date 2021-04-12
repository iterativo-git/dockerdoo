# Dockerized Odoo

This is a flexible and **streamlined** version of most dockerized Odoo projects that you'll find. And one that allows you to deploy with two different methods using the same Dockerfile:

* **Standalone**: As most people use their implementation. With Odoo's source code inside the container. **This is the default**
* **Hosted**: A more practical deployment for **development**, as the HOST (where docker is installed) has the source code, and each container uses this single source.

Dockerdoo is integrated with **VSCode** for fast development and debugging, just install the [Remote Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

> By default this approach does not use the modules availables at the `./custom` directory, as this uses Docker's hosted volumes approach which is considerably slow on Mac and PC. If you'd like to use it this way, just uncomment `./custom:${ODOO_EXTRA_ADDONS}:delegated` from the `dev-vscode.yml`

## Quick usage

To use the **hosted** approach, the Odoo code must be in the `./src` directory, if you also use Enterprise you can add it to the `custom` directory, which is automagically added to your addons_path.

### Standalone

```shell
git clone -b 13.0 git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
docker-compose up
```

### Hosted

```shell
git clone -b 13.0 git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
git clone --depth=1 -b 13.0 git@github.com:odoo/odoo.git src/odoo
docker-compose -f docker-compose.yml -f hosted.yml
```

### Development

#### Standalone development

```shell
git clone -b 13.0 git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
docker-compose -f docker-compose.yml -f dev-standalone.yml up
```

#### Hosted development

```shell
git clone -b 13.0 git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
git clone --depth=1 -b 13.0 git@github.com:odoo/odoo.git src/odoo
docker-compose -f docker-compose.yml -f dev-hosted.yml up
```

## Requirements

To use this docker compose file you should comply with this requirements:

* Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for Windows/Mac or [Docker Engine](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce) for Linux  
* Install [docker-compose](https://docs.docker.com/compose/install/) (This is installed by default on Windows and Mac with Docker installation)
* clone this repository `git@github.com:iterativo-git/dockerdoo.git`

## Running options

There's a bunch of configurations that can be changed in the .env file, allowing you to adapt your installation.

All compose files will raise a **postgres** container to be used by the **Odoo** container, depending on the version that has been set in the `.env` file for `$ODOO_VERSION`

### Standalone Odoo

This is the most straightforward option, as it will install **odoo** [source code](https://github.com/odoo/odoo) inside the *odoo container*, this gives flexibility to the image as it allows you to move it from host to host, and it's more stable-safe for a **production environment**

### Hosted Odoo

This approach is more effective if you'd like have full control over the [source code](https://github.com/odoo/odoo) of the *odoo container*, as it will use the source one on your host, which **must** be located in `./src`, and additionally, if using enterprise, in `./custom/odoo`. Using a hosted Odoo source code allows for easier **debugging**

## Basic Usage

Before running the compose you should evaluate the `.env` file, which sets most variables used in this project.

### Available `docker-compose up` arguments

The Odoo service will use the ***arguments*** defined in the `.env` file, the settings in the ***configuration file*** at `./config/odoo.conf` (if hosted) and the predefined commands from the `docker-compose.yml`

The available overrides to run with `docker-compose` are:

* `up`: This will raise an streamlined Odoo service, with no additional arguments that the ones stated above.

    ```docker
    docker-compose up -d
    ```

* `-f docker-compose.yml -f hosted.yml up`: This will raise an streamlined Odoo service, with no additional arguments that the ones stated above, but hosted in your PC/SERVER outside the container.

    ```docker
    docker-compose -f docker-compose.yml -f hosted.yml up -d
    ```

* `-f docker-compose.yml -f dev-standalone.yml up`: This will raise an Odoo service with `--dev wdb,reload,qweb,werkzeug,xml`. Additionally it will raise a **WDB** service.

    ```docker
    docker-compose -f docker-compose.yml -f dev-standalone.yml up
    ```

* `-f docker-compose.yml -f test-env.yml up`: This will raise an Odoo service with `--dev wdb,qweb,werkzeug,xml`, `--test-enable`, `--stop-after-init`, `--logfile ${ODOO_LOGS_DIR}/odoo-server.log`.

    ```docker
    docker-compose -f docker-compose.yml -f test-env.yml up -d
    ```

As shown above, all this services are recommended to be run on **detached mode**: `-d`, as this is the most common use case.

### Project Structure

```bash
your-project/
 ├── resources/         # Scripts for service automation
 ├── src/
 │   └── odoo/          # Just required if using hosted source code
 │
 ├── config/
 │   └── odoo.conf      # Hosted configuration file for hosted environment
 ├── custom/            # Custom modules goes here, same level hierarchy **REQUIRED**
 │   ├── iterativo/
 │   ├── OCA/
 │   ├── enterprise/
 │   └── /
 ├── ...                # Common files (.gitignore, etc.)
 ├── .env               # Single source of environment definition
 ├── Dockerfile         # Single source of image definition
 ├── docker-compose.yml             # The opionated version
 └── docker-compose.override.yml    # Your custom version
```

### Extra addons

You can put all your **custom addons** in the folder `./custom/`, those will be automatically added to your `addons_path` thanks to the script in `./resources/getaddons.py`

## Credits

Mainly based on dockery-odoo work by:

* [David Arnold](https://github.com/blaggacao) ([XOE Solutions](https://xoe.solutions))

Bunch of ideas taken from:

* [Odoo](https://github.com/odoo) ([docker](https://github.com/odoo/docker))
* [OCA](https://github.com/OCA) ([maintainer-quality-tools](https://github.com/OCA/maintainer-quality-tools))
* [Ingeniería ADHOC](https://github.com/jjscarafia) ([docker-odoo-adhoc](https://github.com/ingadhoc/docker-odoo-adhoc))

## WIP

* Swarm / Kubernetes considerations (secrets, etc.)
