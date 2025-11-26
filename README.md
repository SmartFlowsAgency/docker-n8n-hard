# Hardened n8n Docker Stack

## Objective
Deploy a production-ready n8n automation server with enterprise-grade security hardening and automated SSL certificate management.

## Architecture
- **n8n**: Workflow automation engine with PostgreSQL backend
- **PostgreSQL**: Hardened database with capability restrictions
- **nginx**: Reverse proxy with SSL termination
- **certbot**: Automated SSL certificate provisioning/renewal
- **Init Containers**: Permission management and service orchestration

![n8n Hardened Stack Architecture](docs/assets/architecture.svg)

*Figure: High-level architecture of the hardened n8n Docker deployment.*

## Security Features
- **Read-only filesystems** with tmpfs for writable areas
- **Dropped capabilities** (ALL) with minimal required capabilities added back
- **no-new-privileges** security option
- **Network segmentation** (separate networks for cert management vs app)
- **Permission isolation** via dedicated init containers
- **SELinux-compatible** volume labeling

## Key Components
1. **permissions-init**: Sets up all volume ownership before service startup
2. **nginx-certbot + certbot**: Certificate acquisition (profile: cert-init)
3. **nginx-rproxy**: Production reverse proxy with SSL
4. **postgres**: Hardened database with minimal capabilities
5. **n8n**: Workflow engine with tmpfs mounts for npm/cache

---

## 🚀 Quick Start

**Prerequisites:**
- Docker and Docker Compose installed
- A domain name pointed to your server’s IP

### 1. Clone the Repository
```sh
git clone <your-repo-url>
cd docker-n8n-hard
```

### 2. Run the Interactive Setup
```sh
./dn8nh.sh setup
```
- Renders environment files from `env/vars.yaml` into `env/.env.*`.
- Ensures Docker volumes and renders Nginx configs in `nginx-conf/`.
- Obtains initial SSL certificates using the cert-init profile (requires DNS to point to this host).

### 3. Deploy the Stack
```sh
./dn8nh.sh deploy
```
- Runs the permissions-init container to set volume permissions.
- Starts Postgres, n8n, and hardened Nginx in the correct order.
- Waits for all services to become healthy.


---

## ⚙️ Management Commands

| Command | Description |
|------------------------|----------------------------------------------|
| `./dn8nh.sh setup` | Render envs, ensure volumes, render nginx, obtain SSL certs |
| `./dn8nh.sh install` | Alias for setup |
| `./dn8nh.sh deploy` | Orchestrated deployment of all services |
| `./dn8nh.sh up` | Alias for deploy |
| `./dn8nh.sh down` | Stop and remove all services |
| `./dn8nh.sh logs` | Tail logs for all services |
| `./dn8nh.sh status` | Show service status and health |
| `./dn8nh.sh backup` | Backup PostgreSQL and n8n data |
| `./dn8nh.sh restore` | Restore data from backups (interactive, latest, or manual) |
| `./dn8nh.sh cert-init` | Obtain SSL certificates (advanced/manual) |
| `./dn8nh.sh cert-renew` | Manually renew SSL certificates |

---

## 💾 Backup and Restore

The stack includes simple commands for backing up and restoring your critical data volumes.

- **`./dn8nh.sh backup`**: Creates compressed `tar.gz` archives of your `n8n` and `postgres` data volumes in the `backups/` directory.
- **`./dn8nh.sh restore`**: Provides a flexible restore system. You can restore the latest backups, select archives interactively, or specify exact files for each volume.

For detailed options and examples, see the [Operations & Maintenance Guide](docs/OPERATIONS.md).

## 📁 Project Structure

```
.
├── dn8nh.sh            # Main entrypoint for all operations
├── scripts/             # Setup, build, deploy, backup scripts
├── entrypoints/         # Container entrypoint scripts
├── nginx-conf/          # Nginx configuration and templates
├── docker-compose.yml   # Main Compose file
├── .env                 # Environment configuration (generated)
├── docs/                # Deep-dive documentation
└── ...
```

---

## 🛠️ Troubleshooting & Notes

- **Do not** use `docker compose up` directly; always use `./dn8nh.sh deploy` for correct startup order and permission handling.
- If setup or build fails, check for missing prerequisites, domain misconfiguration, or permission issues.
- All secrets are stored in `.env`—keep this file secure.
- For advanced details, see the `docs/` directory.

---

## 🔗 Further Reading
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Service and network deep dive
- [docs/SECURITY.md](docs/SECURITY.md) — Security model and rationale
- [docs/OPERATIONS.md](docs/OPERATIONS.md) — Maintenance, backup, and troubleshooting
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) — Environment variables reference

---

## Roadmap

- Analyze logs with free calls to groq.
- Gracefully downgrade n8n to old version.

See [docs/ROADMAP.md](docs/ROADMAP.md) for future plans and feature ideas.

---

## Security Trade-offs
- PostgreSQL requires `DAC_OVERRIDE` capability for internal file operations
- Nginx needs `SETUID/SETGID` for privilege dropping
- NPM package installs use tmpfs (non-persistent for security)