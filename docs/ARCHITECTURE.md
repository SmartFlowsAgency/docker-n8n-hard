# Architecture Deep Dive: Hardened n8n Docker Stack

![n8n Hardened Stack Architecture](assets/architecture.svg)

*Figure: High-level architecture of the hardened n8n Docker deployment.*

This document explains the architecture, service responsibilities, and container relationships for the hardened n8n deployment.

--- 

## Service Breakdown

### 1. permissions-init
- **Role:** Prepares all Docker volumes with correct ownership and permissions before any service starts.
- **Runs:** Once per deployment, as an init container.
- **Security:** Runs as root in a minimal Alpine container. No network access.

### 2. n8n-nginx-certbot (cert-init profile)
- **Role:** Temporary reverse proxy for serving ACME HTTP-01 challenges during SSL certificate acquisition/renewal.
- **Runs:** Only during `cert-init` operations.
- **Security:** Minimal privileges, only port 80 exposed.

### 3. n8n-certbot (cert-init profile)
- **Role:** Requests and renews SSL certificates from Let’s Encrypt.
- **Runs:** Only during `cert-init` operations.
- **Security:** Mounts required volumes for certificate persistence.

### 4. n8n-postgres
- **Role:** Persistent database for n8n workflows and credentials.
- **Security:** Hardened with dropped capabilities, tmpfs for sensitive dirs, custom entrypoint for permissions.
- **Persistence:** Uses a Docker volume for `/var/lib/postgresql/data`.

### 5. n8n
- **Role:** Main workflow automation engine.
- **Security:** Runs as non-root, read-only root filesystem, minimal capabilities, tmpfs for cache/npm.
- **Persistence:** Uses Docker volumes for data and files.

### 6. n8n-nginx-hard
- **Role:** Production reverse proxy, SSL termination, and static file serving.
- **Security:** Drops all capabilities except those required for binding and privilege dropping, read-only config, tmpfs for /tmp.
- **Persistence:** Logs and cache stored in Docker volumes.

---

## Networking
- **n8n-network:** Main app network for n8n, postgres, and nginx-stark.
- **cert-net:** Isolated network for certificate management (n8n-nginx-certbot, certbot).

---

## Data Persistence & Volumes
- **n8n_data:** n8n user data and workflow state
- **n8n_files:** n8n file uploads and attachments
- **n8n-postgres_data:** PostgreSQL database files
- **n8n-certbot-etc:** Let’s Encrypt certificates
- **n8n-certbot-www:** ACME challenge webroot
- **n8n-nginx_logs:** Nginx logs

---

## Orchestration Flow
1. **permissions-init** ensures all volumes are correctly owned.
2. **cert-init** profile (`nginx-acme` + `certbot`) runs for SSL certificate bootstrapping.
3. **deploy** starts core services (`postgres`, `n8n`, `nginx-stark`) in correct order, waiting for health.

---

For more details, see [SECURITY.md](SECURITY.md) and [OPERATIONS.md](OPERATIONS.md).
