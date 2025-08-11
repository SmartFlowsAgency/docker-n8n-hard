# Hardened n8n Docker Setup

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
2. **n8n-nginx-certbot + certbot**: Certificate acquisition (profile: cert-init)
3. **nginx-stark**: Production reverse proxy with SSL
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
- Prompts for your domain and email.
- Generates a secure `.env` file.
- Sets executable permissions on all scripts.

### 3. Build Configs & Obtain SSL Certificates
```sh
./dn8nh.sh build
```
- Generates the Nginx HTTPS config from your domain.
- Runs the certificate initialization containers (`n8n-nginx-certbot`, `certbot`) to obtain or renew SSL certificates.

### 4. Deploy the Stack
```sh
./dn8nh.sh deploy
```
- Runs the permissions-init container to set volume permissions.
- Starts Postgres, n8n, and hardened Nginx in the correct order.
- Waits for all services to become healthy.

---

## ⚙️ Management Commands

| Command                | Description                                  |
|------------------------|----------------------------------------------|
| `./dn8nh.sh setup`    | Interactive setup and .env creation          |
| `./dn8nh.sh build`    | Generate configs & obtain SSL certificates   |
| `./dn8nh.sh deploy`   | Orchestrated deployment of all services      |
| `./dn8nh.sh down`     | Stop and remove all services                 |
| `./dn8nh.sh logs`     | Tail logs for all services                   |
| `./dn8nh.sh backup`   | Backup PostgreSQL and n8n data               |
| `./dn8nh.sh cert-renew` | Manually renew SSL certificates           |

---

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

- **Do not** use `docker-compose up` directly; always use `./dn8nh.sh deploy` for correct startup order and permission handling.
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