# Dockerized Odoo for Odoo 11.0 & 12.0 (BETA)

This is a flexible and **streamlined** version of most Odoo docker projects that you'll find. And one that allows you to deploy with two different methods using the same docker-compose:

* **Standalone**: As most people use their implementation. Each container with an Odoo instance inside
* **Hosted**: A more practical implementation and **cheaper** on resources, as the HOST (where docker is installed) has the application (Odoo), and each container uses this single source. **This is the default**.

## Quick usage

### Hosted

```shell
git clone git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
git clone --depth=10 -b 12.0 git@github.com:odoo/odoo.git src/odoo/ce
docker-compose up odoo
```

#### Standalone

In the **.env** file set `INSTALL_TYPE=standalone`

```shell
git clone git@github.com:iterativo-git/dockerdoo.git && cd dockerdoo
docker-compose up odoo
```

## Requirements

To use this docker compose file you should comply with this requirements:

* Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for Windows/Mac or [Docker Engine](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce) for Linux  
* Install [docker-compose](https://docs.docker.com/compose/install/) (This is installed by default on Windows and Mac with Docker installation)
* clone this repository `git@github.com:iterativo-git/dockerdoo.git`

## Running options

There's mainly two ways to deploy with this compose, both available to be configured on the .env file using the `$INSTALL_TYPE` variable, choosing between `standalone` or `hosted` as options.

Both options will raise a **postgres** container to be used by an **Odoo** container in v11 or v12, depending on the version that has been set in the `.env` file for `$ODOO_VERSION`

### Standalone Odoo

This is the most straightforward option, as it will install **odoo** [source code](https://github.com/odoo/odoo) inside the *odoo container*, this gives flexibility to the image as it allows you to move it from host to host, and it's more stable-safe for a **production environment**

### Hosted Odoo

This approach is more effective if you'd like have full control over the [source code](https://github.com/odoo/odoo) on the *odoo container*, as it will be using the source one on your host, which **must** be located (in your host) in `./src/odoo/ce`, and additionally, if using enterprise, in `./src/odoo/ee`

Using a hosted Odoo allows easier **debugging**, **testing** and **shell**; use cases that are also easy to deploy using the docker-compose.

## Basic Usage

Before running the compose you should evaluate the `.env` file, which sets most variables used in this project. The **most** important variable to set is **`INSTALL_TYPE`** which decides if your installation will be **hosted** or **standalone**. hosted is selected by default in the compose-file if no selection is made; which assumes you already have Odoo's source in your host.

### Available `docker-compose up` arguments

This compose file must always be run with an *argument*, running it without one will try to run all available services in it, which will collides as the compose is using `YAML` inheritance from the main service, including the ports that will collide.

All services will go up using the ***database arguments*** defined in the `.env` file, the settings in the ***configuration file*** at `./config/odoo.conf` and the predefined commands from the `docker-compose.yml`

The available arguments to run with `docker-compose up` are:

* `odoo`: This will raise an streamlined Odoo service, with no additional arguments that the ones stated above.

    ```docker
    docker-compose up -d odoo
    ```

* `dev`: This will raise an Odoo service with `--dev wdb,reload,qweb,werkzeug,xml`. Additionally it will raise a **WDB** service.

    ```docker
    docker-compose up -d dev
    ```

* `tests`: This will raise an Odoo service with `--dev wdb,qweb,werkzeug,xml`, `--test-enable`, `--stop-after-init`, `--logfile ${ODOO_LOGS_DIR}/odoo-server.log`. Additionally it will raise a **WDB** service.

    ```docker
    docker-compose up -d tests
    ```
As shown, all this services are recommended to be run on **detached mode**: `-d`, as this is the most common use case.

### Project Structure

```bash
your-project/
 ├── resources/         # Scripts for service automation
 ├── src/
 │   ├── odoo/
 │   │   ├── ce/        # Source from git@github.com:odoo/odoo.git
 │   │   └── ee/        # Source from git@github.com:odoo/enterprise.git
 │   └── .../           # Optionally, other sources like OCA
 │
 ├── custom/            # *Your* custom modules goes here.
 │   ├── module_1/
 │   └── .../
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

* More customizable odoo.conf
* Swarm considerations (secrets, etc.)
* Optimized images based on multi-stage (OS, python, dependencies, odoo, custom)