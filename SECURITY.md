# PostgreSQL security (dockerdoo)

## Risk

Default `postgres` image creates `POSTGRES_USER` as **superuser** and appends `host all all all` to `pg_hba.conf`. Attackers use `COPY FROM PROGRAM` after guessing weak credentials (PGMiner / unicorn botnets).

Init scripts in `resources/postgres-init/` run **only on empty** `psql` volume.

## New deploy

```bash
cp .env.example .env   # set strong passwords; sync POSTGRES_* and DB_ENV_*
docker compose up -d
```

Verify:

```bash
docker compose exec db psql -U odoo -d postgres -c \
  "SELECT rolsuper, rolreplication FROM pg_roles WHERE rolname='odoo';"
docker compose exec db grep '^host' /var/lib/postgresql/data/pgdata/pg_hba.conf
```

Expected: `rolsuper=f`, no `host all all all`, rule for `DOCKER_ODONET_SUBNET` (default `172.28.0.0/16`).

## Existing volume (already has data)

Init does **not** re-run. Apply manually:

### 0. Backup first

```bash
cd /path/to/your-stack
BACKUP=~/backup_$(date +%Y%m%d_%H%M).sql.gz
docker compose exec -T db pg_dumpall -U odoo | gzip > "$BACKUP"
gzip -t "$BACKUP" && ls -lh "$BACKUP"
```

### 1. Sync `.env` credentials

Entrypoint prioritizes `DB_ENV_*` over `POSTGRES_*`. Both must match:

```env
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<strong-password>
DB_ENV_POSTGRES_USER=odoo
DB_ENV_POSTGRES_PASSWORD=<strong-password>
```

### 2. Recreate DB container (cleans /tmp, /dev/shm)

```bash
docker compose up -d --force-recreate db
until docker compose exec db pg_isready -U odoo; do sleep 2; done
```

Does not remove the `psql` volume.

### 3. IoC cleanup (if infection was active)

Inside the `db` container:

- Kill processes: `dns-filter`, `unicorn`, `/tmp/.usr_*`
- Remove: `/tmp/.dl_*`, `/dev/shm/.unicorn`, `/var/lib/postgresql/.claude/`
- Block in `/etc/hosts`: `31.77.227.130`, `xmr.kryptex.network`

### 4. SQL hardening

Run in order (`NOREPLICATION` before `NOSUPERUSER`):

```sql
ALTER USER odoo PASSWORD '<strong-password>';
ALTER USER odoo NOREPLICATION;
ALTER USER odoo NOSUPERUSER;
ALTER USER odoo CREATEDB;
REVOKE pg_execute_server_program FROM odoo;
```

Verify: `SELECT rolsuper, rolreplication FROM pg_roles WHERE rolname='odoo';` → both `f`.

### 5. Restrict `pg_hba.conf`

Edit `/var/lib/postgresql/data/pgdata/pg_hba.conf`. Replace:

```
host all all all md5
```

With (use your stack's `DOCKER_ODONET_SUBNET`):

```
host all all 172.28.0.0/16 md5
host all all 127.0.0.1/32 md5
```

Reload: find postgres PID and `kill -HUP <pid>` (or `SELECT pg_reload_conf();` if still superuser).

Detect subnet: `docker network inspect <project>_odoonet --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'`

### 6. Recreate Odoo

```bash
docker compose up -d --force-recreate odoo
```

Regenerates `/etc/odoo/odoo.conf` from `.env`.

### 7. Verification

| Check | Criterion |
|-------|-----------|
| No miner | `docker top <project>-db-1` without `dns-filter`/`unicorn` |
| CPU DB | idle < 10% |
| Hardened role | `rolsuper = f` |
| Odoo connects | logs without `password authentication failed` |
| COPY blocked | `COPY (SELECT 1) TO PROGRAM 'id';` fails for user `odoo` |

## Dev

`~/.ssh` mount is only in `dev-hosted.yml` / `dev-standalone.yml`, not in base `docker-compose.yml`.
