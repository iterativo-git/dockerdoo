#!/bin/bash

set -x

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${PGHOST:=${DB_PORT_5432_TCP_ADDR}}
: ${PGPORT:=${DB_PORT_5432_TCP_PORT}}
: ${PGUSER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER}}}
: ${PGPASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD}}}

# set all variables

function getAddons() {

    EXTRA_ADDONS_PATHS=$(python3 getaddons.py ${ODOO_EXTRA_ADDONS} 2>&1)
}

getAddons

if [ ! -f ${ODOO_RC} ]; then
echo "
[options]
addons_path = ${ODOO_ADDONS_BASEPATH}
admin_passwd = ${ADMIN_PASSWORD}
data_dir = ${ODOO_DATA_DIR}
db_host = ${PGHOST}
db_maxconn = ${DB_MAXCONN}
db_password = ${PGPASSWORD}
db_port = ${PGPORT}
db_sslmode = ${DB_SSLMODE}
db_template = ${DB_TEMPLATE}
db_user = ${PGUSER}
dbfilter = ${DBFILTER}
db_name = ${DBNAME}
http_interface = ${HTTP_INTERFACE}
http_port = ${HTTP_PORT}
limit_request = ${LIMIT_REQUEST}
limit_memory_hard = ${LIMIT_MEMORY_HARD}
limit_memory_soft = ${LIMIT_MEMORY_SOFT}
limit_time_cpu = ${LIMIT_TIME_CPU}
limit_time_real = ${LIMIT_TIME_REAL}
limit_time_real_cron = ${LIMIT_TIME_REAL_CRON}
list_db = ${LIST_DB}
log_db = ${LOG_DB}
log_db_level = ${LOG_DB_LEVEL}
logfile = ${LOGFILE}
log_handler = ${LOG_HANDLER}
log_level = ${LOG_LEVEL}
max_cron_threads = ${MAX_CRON_THREADS}
proxy_mode = ${PROXY_MODE}
server_wide_modules = ${SERVER_WIDE_MODULES}
smtp_password = ${SMTP_PASSWORD}
smtp_port = ${SMTP_PORT}
smtp_server = ${SMTP_SERVER}
smtp_ssl = ${SMTP_SSL}
smtp_user = ${SMTP_USER}
test_enable = ${TEST_ENABLE}
unaccent = ${UNACCENT}
without_demo = ${WITHOUT_DEMO}
workers = ${WORKERS}
running_env = ${RUNNING_ENV}" > $ODOO_RC
fi

if [ -z "$EXTRA_ADDONS_PATHS" ]; then
    echo "The variable \$EXTRA_ADDONS_PATHS is empty, using default addons_path"
else
    if [ "$PIP_AUTO_INSTALL" -eq "1" ]; then
        find $ODOO_EXTRA_ADDONS -name 'requirements.txt' -exec pip3 install --progress-bar off --user -r {} \;
    fi
    sed -i "s|addons_path = *|addons_path = ${EXTRA_ADDONS_PATHS},|" $ODOO_RC
fi


DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
   fi;
}

check_config "db_host" "$PGHOST"
check_config "db_port" "$PGPORT"
check_config "db_user" "$PGUSER"
check_config "db_password" "$PGPASSWORD"

case "$1" in
    -- | odoo | ${ODOO_CMD})
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        elif [[ "$RUN_TESTS" -eq "1" ]] ; then
            if [ -z "$EXTRA_MODULES" ]; then
                EXTRA_MODULES=$(python3 -c "from getaddons import get_modules; print(','.join(get_modules('${ODOO_EXTRA_ADDONS}', depth=3)))")
            fi
            if [ "$WITHOUT_TEST_TAGS" -eq "1" ]; then
                exec odoo "$@" "--test-enable" "--stop-after-init" "-i" "${EXTRA_MODULES}" "-d" "${TEST_DB:-test}" "${DB_ARGS[@]}"
            else
                # Append exclusion tag for the flaky profiler test
                test_tags="${EXTRA_MODULES},-base:TestPerformance.test_frequencies_1ms_sleep"
                exec odoo "$@" "--test-enable" "--stop-after-init" "-i" "${EXTRA_MODULES}" "--test-tags" "${test_tags}" "-d" "${TEST_DB:-test}" "${DB_ARGS[@]}"
            fi
            
        else
            if [[ "$UPGRADE_ODOO" -eq "1" ]] ; then
                ODOO_DB_LIST=$(psql -X -A -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d postgres -t -c "SELECT STRING_AGG(datname, ' ') FROM pg_database WHERE datdba=(SELECT usesysid FROM pg_user WHERE usename=current_user) AND NOT datistemplate and datallowconn")
                for db in ${ODOO_DB_LIST}; do
                    click-odoo-update --ignore-core-addons -d $db -c ${ODOO_RC} --log-level=error
                    echo "The Database ${db} has been updated"
                done
            fi
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
