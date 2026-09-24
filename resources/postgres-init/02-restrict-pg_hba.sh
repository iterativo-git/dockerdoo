#!/bin/bash
# Restrict pg_hba to the docker odoonet subnet (+ localhost).
# Requires a fixed subnet in docker-compose.yml (DOCKER_ODONET_SUBNET).
set -euo pipefail

: "${PGDATA:?PGDATA must be set}"

PG_HBA="${PGDATA}/pg_hba.conf"
SUBNET="${DOCKER_ODONET_SUBNET:-172.28.0.0/16}"

if [[ ! -f "${PG_HBA}" ]]; then
	echo "postgres-init: ${PG_HBA} not found" >&2
	exit 1
fi

# Reuse auth method from the wide-open rule before removing it (md5 on PG12, scram on PG14+).
AUTH_METHOD="$(grep -E '^host[[:space:]]+all[[:space:]]+all[[:space:]]+all[[:space:]]+' "${PG_HBA}" | awk '{print $NF}' | head -1)"
AUTH_METHOD="${AUTH_METHOD:-md5}"

# Drop wide-open rule: host all all all <auth>
sed -i -E '/^host[[:space:]]+all[[:space:]]+all[[:space:]]+all[[:space:]]+/d' "${PG_HBA}"

{
	echo "# dockerdoo secure init"
	echo "host all all ${SUBNET} ${AUTH_METHOD}"
	echo "host all all 127.0.0.1/32 ${AUTH_METHOD}"
	echo "host all all ::1/128 ${AUTH_METHOD}"
} >> "${PG_HBA}"

echo "postgres-init: pg_hba restricted to ${SUBNET} (auth: ${AUTH_METHOD})"
