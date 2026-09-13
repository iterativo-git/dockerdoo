#!/bin/bash
# Runs once on first DB init (empty psql volume).
# Requires POSTGRES_USER from the official postgres image entrypoint.
set -euo pipefail

: "${POSTGRES_USER:?POSTGRES_USER must be set}"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "postgres" <<-EOSQL
	-- Order matters: NOREPLICATION before NOSUPERUSER (same as runtime playbook).
	ALTER USER ${POSTGRES_USER} NOREPLICATION;
	ALTER USER ${POSTGRES_USER} NOSUPERUSER;
	ALTER USER ${POSTGRES_USER} CREATEDB;
	REVOKE pg_execute_server_program FROM ${POSTGRES_USER};
EOSQL

echo "postgres-init: hardened role '${POSTGRES_USER}' (nosuperuser, noreplication, no COPY FROM PROGRAM)"
