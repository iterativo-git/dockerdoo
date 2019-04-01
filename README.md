# Dockerized Odoo for Odoo 11.0 & 12.0 (BETA)

## Another dockerized Odoo (?)

Kind of, but this is a more flexible and **streamlined** version of most docker projects that you'll find. And more importanly, with a single docker-compose you have the two main mplementation methods:

* **Standalone**: As most people use their implementation. Each container with an Odoo instance inside
* **Hosted**: A more practical implementation and **cheaper** on resources, as the HOST (where docker is installed) has the application (Odoo), and each container uses this single source.

## Requirements

To use this docker compose file you should comply with this requirements:

* install pip `sudo apt-get install python-pip`
* Install ![docker engine](https://docs.docker.com/install/)
* Install ![docker-compose](https://docs.docker.com/compose/install/)
* clone this repository `git@github.com:iterativo-git/dockerdoo.git`

## Running options

There's mainly two ways to deploy with this compose, both available to be configured on the .env file using the `$INSTALL_TYPE` variable, choosing between `standalone` or `bridged` as options.

Both options will raise a **postgres** container to be used by an **Odoo** container in v11 or v12, depending on the version that has been set in the `.env` file for `$ODOO_VERSION`

### Standalone Odoo

This is the most straightforward option, as it will install **odoo** ![source code](https://github.com/odoo/odoo) inside the *odoo container*, this gives flexibility to the image as it allows you to move it from host to host, and it's more stable-safe for a **production environment**

### Bridged Odoo

This approach is more effective if you'd like have full control over the ![source code](https://github.com/odoo/odoo) on the *odoo container*, as it will be using the source one on your host, which **must** be localed (in your host) in `./src/odoo/ce`, and additionally, if using enterprise, in `./src/odoo/ee`

Using a bridged Odoo allows easier **debugging**, **testing** and **shell**; use cases that are also easy to deploy using the docker-compose.

## How to Use

Before running the compose you should evaluate the `.env` file, which sets most variables used in this project. The **most** important variable to set is **`INSTALL_TYPE`** which decides if your installation will be **bridged** or **standalone**. bridged is selected by default in the compose-file if no selection is made; which assumes you already have Odoo's source in your host.

### Available `docker-compose up` arguments

This compose file must always be run with an *argument*, running it withouth one will try to run all available services in it, which will collides as the compose is using `YAML` inheritance from the main service, including the ports that will collide.

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

### Extra addons

You can put all your **custom addons** in the folder `./custom_addons/`, those will be autotically added to your `addons_path` thanks to the script in `./resources/getaddons.py`