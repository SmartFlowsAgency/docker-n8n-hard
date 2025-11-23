# Scripts Catalog

This catalog documents the scripts included in this repository, their purpose, usage, dependencies, and any known gaps.

---

## Top-level Orchestrator

- **dn8nh.sh**
  - Purpose: Main entrypoint for managing the stack.
  - Usage: `./dn8nh.sh <command>`
  - Commands and current wiring:
    - `setup` → `scripts/setup.sh`
    - `install` (alias) → `scripts/setup.sh`
    - `deploy` → `scripts/deploy.sh`
    - `up` (alias) → `scripts/deploy.sh`
    - `down` → `docker compose down`
    - `clean` → `scripts/clean.sh`
    - `restart` → `docker compose restart`
    - `logs` → `docker compose logs -f`
    - `ps` → `docker compose ps`
    - `status` → `scripts/status.sh`
    - `backup` → `scripts/backup.sh`
    - `cert-init` → `scripts/certbot/certbot_build.sh`
    - `cert-renew` → `scripts/certbot/certbot_renew.sh`
  - Notes:
    - Performs safety check for port 80 conflicts between prod nginx and cert-init nginx.
    - Validates presence of `env/` and `nginx-conf/` before deploy/cert commands.
    - Developer/test commands are documented separately in builder docs.

---

## Operations

- **scripts/deploy.sh**
  - Purpose: Orchestrates safe startup for the hardened stack.
  - Highlights:
    - Defaults `COMPOSE_PROFILES=prod`.
    - Loads all `env/.env*` overlays and optional project `.env`.
    - Cleanup helpers: remove conflicting networks, containers, and legacy n8n networks.
    - Waits for: permissions-init to exit, Postgres healthy, n8n healthy, nginx healthy (if certs exist).
    - Checks for existing SSL certs in volume `${DN8NH_INSTANCE_NAME}_n8n-certbot-etc` and allows `--http` to proceed without certs.
    - Extracts existing n8n `encryptionKey` from `n8n_data` volume and injects into `env/.env.n8n` if present.
  - Usage: `./dn8nh.sh deploy [--http]`

- **scripts/clean.sh**
  - Purpose: Remove containers, networks, and optionally volumes and orphans.
  - Usage:
    - `scripts/clean.sh` (containers + networks)
    - `scripts/clean.sh --volumes|-v` (also delete volumes) [DESTRUCTIVE]
    - `scripts/clean.sh --all|-a` (delete volumes + prune orphans) [DESTRUCTIVE]

- **scripts/backup.sh**
  - Purpose: Back up key Docker volumes for the instance.
  - Volumes: `${PROJECT}_n8n_data`, `${PROJECT}_n8n_files`, `${PROJECT}_n8n-postgres_data` (+ certs if `--include-certs`).
  - Derives project prefix from `DN8NH_INSTANCE_NAME` or `COMPOSE_PROJECT_NAME`.
  - Usage: `scripts/backup.sh [--include-certs] [--pause] [--dry-run] [--dest=PATH]`

- **scripts/status.sh**
  - Purpose: Shows service status, health, basic connectivity to `N8N_HOST`, and resource table.
  - Usage: `./dn8nh.sh status`

---

## Setup

- **scripts/setup.sh**
  - Purpose: Prepare artifact and obtain initial SSL certificates: render env files, ensure volumes, render nginx configs, then run cert-init flow.
  - Steps:
    - Downloads `yq` to `bin/yq` if missing.
    - Renders `env/.env.*` from `env/vars.yaml` via `scripts/setup/render_env.sh`.
    - Ensures external volumes exist via `scripts/setup/ensure_volumes.sh` (requires `.env` with `DN8NH_INSTANCE_NAME`).
    - Renders nginx templates in `nginx-conf/` using `env/.env.certbot` via `scripts/setup/render_nginx_conf.sh`.
    - Runs `scripts/certbot/certbot_build.sh` to obtain certificates (requires domain DNS pointing at host).
  - Usage: `./dn8nh.sh setup [--no-interactive]`

- **scripts/setup/ensure_volumes.sh**
  - Purpose: Create external volumes with prefix `DN8NH_INSTANCE_NAME`.
  - Requires: project `.env` with `DN8NH_INSTANCE_NAME` set.

- **scripts/setup/render_env.sh**
  - Purpose: Render `env/.env.<section>` files from `env/vars.yaml`.
  - Features:
    - Reuses previous `POSTGRES_PASSWORD` if present in existing `env/.env.postgres`.
    - Treats any key matching `*PASSWORD|*SECRET|*TOKEN|*KEY|*ENCRYPTION|*AUTH` as sensitive in debug logs.
    - Honors overrides from candidate files: project `.env`, parent `.env*`, and `env/.env*`.
  - Usage: `scripts/setup/render_env.sh env/vars.yaml`

- **scripts/setup/render_nginx_conf.sh**
  - Purpose: Render `nginx-*.conf.tpl` to `nginx-*.conf` using specific env file (typically `env/.env.certbot`).
  - Notes: Restricts `envsubst` variables to `N8N_HOST` and `LETSENCRYPT_DOMAIN` to avoid clobbering nginx internal vars.

---

## Certificate Management

- **scripts/certbot/certbot_build.sh**
  - Purpose: Bring up temporary nginx and certbot to obtain certificates.
  - Behavior:
    - Sets `COMPOSE_PROFILES=cert-init`.
    - Removes previous `n8n-nginx-certbot` and `n8n-certbot` containers.
    - Runs: `n8n-hard_permissions-init`, `n8n-nginx-certbot`, `n8n-certbot` with `--abort-on-container-exit`.
  - Used by: `./dn8nh.sh setup` and `./dn8nh.sh cert-init`.
  - Requires: DNS A/AAAA record for `N8N_HOST` pointing at the server.

- **scripts/certbot/certbot_renew.sh**
  - Purpose: Renewal flow using webroot; reloads or restarts nginx if running.

- Entrypoint: **entrypoints/certbot_entrypoint.sh**
  - Purpose: Run certbot `certonly --webroot`, optionally in staging/dry-run; then signal the temporary nginx to stop.
  - Env: `LETSENCRYPT_EMAIL` (required), `N8N_HOST` (or `LETSENCRYPT_DOMAIN`), `CERTBOT_STAGING`, `CERTBOT_DRY_RUN`.

- Entrypoint: **entrypoints/nginx-acme_entrypoint.sh**
  - Purpose: Legacy helper that runs nginx until a hardcoded cert path appears, then exits.
  - Note: Uses a hardcoded domain path; appears unused in current compose.

---

## Service Entrypoints

- **entrypoints/permissions_init.sh**
  - Purpose: Initialize ownership/permissions for volumes used by Postgres, n8n, certbot, and nginx logs.

- **entrypoints/postgres_entrypoint.sh**
  - Purpose: Ensure Postgres data dir is owned by UID/GID 999 before deferring to official entrypoint.

---

## Compose Integration (Reference)

- `docker-compose.yml` services of interest:
  - `n8n-hard_permissions-init` → runs `entrypoints/permissions_init.sh`.
  - `n8n-nginx-certbot` (profile `cert-init`) → uses `nginx-conf/nginx-http.conf` for ACME http-01.
  - `n8n-certbot` (profile `cert-init`) → uses `entrypoints/certbot_entrypoint.sh`.
  - `n8n-postgres` → prod profile service; healthchecked.
  - `n8n-hard` → prod profile service; healthchecked; mounts volumes and logs.
  - `n8n-hard-nginx-prod` → prod profile service; uses `nginx-conf/nginx-https.conf` and certbot volume.

---

## Known Gaps and Inconsistencies

- `entrypoints/nginx-acme_entrypoint.sh` has a hardcoded cert path; appears legacy/unused.

---

## Environment Files (Reference)

- Located in `env/` and rendered by setup:
  - `.env.n8n`
  - `.env.postgres`
  - `.env.certbot`
  - `.env.overlay` (local overrides)
  - `vars.yaml` (template source for env files)

