#!/bin/bash -x

set -e

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

function getAddons() {
    
    ODOO_EXTRA_ADDONS=$(python3 getaddons.py ${ODOO_EXTRA_ADDONS:-'/mnt/extra-addons'} 2>&1)
}

getAddons

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
   fi;
}

if [ -z "$ODOO_EXTRA_ADDONS" ]
then
      echo "The variable \$var is empty, using default addons_path"
      check_config "addons-path" "$ODOO_ADDONS_BASEPATH"
else
      check_config "addons-path" "$ODOO_ADDONS_BASEPATH,$ODOO_EXTRA_ADDONS"
fi

check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

./wait_postgres.sh

case "$1" in
    -- | odoo | ${ODOO_CMD})
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec ${ODOO_CMD} "$@"
        else
            exec ${ODOO_CMD} "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        exec ${ODOO_CMD} "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1