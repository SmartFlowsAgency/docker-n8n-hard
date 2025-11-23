# Configuration (Artifact Users)

This guide explains how to configure the artifact before running setup and deploy.

---

## Required values

| Variable           | Description                                   | Example                |
|--------------------|-----------------------------------------------|------------------------|
| N8N_HOST           | Public domain name for your n8n instance       | n8n.example.com        |
| LETSENCRYPT_EMAIL  | Email for Let's Encrypt notifications          | admin@example.com      |

Notes:
- Use a domain that resolves to this server before running `./dn8nh.sh setup`.
- Certificates are obtained during setup via the cert-init flow.

## Common optional values

| Variable                  | Description                                              | Example / Default |
|---------------------------|----------------------------------------------------------|-------------------|
| N8N_BASIC_AUTH_ACTIVE     | Enable basic auth for n8n UI/API                         | true              |
| N8N_BASIC_AUTH_USER       | Username for basic auth                                  | admin             |
| N8N_BASIC_AUTH_PASSWORD   | Password for basic auth                                  | (generated)       |
| N8N_ENCRYPTION_KEY        | Key to encrypt credentials in n8n                        | (generated)       |
| N8N_EDITOR_BASE_URL       | Public URL for n8n editor                                | https://your.domain |
| TZ                        | Timezone for containers                                  | UTC               |
| DN8NH_INSTANCE_NAME       | Instance/project name used to prefix volumes             | production        |
| COMPOSE_PROJECT_NAME      | Compose project name (defaults to DN8NH_INSTANCE_NAME)   | production        |

Most other values are pre-set for hardened defaults and do not require changes.

---

## Env overlays (how configuration is applied)

- The setup process renders environment files under `env/` from a template.
- Files you will see/use in the artifact:
  - `env/.env.n8n` — n8n service settings
  - `env/.env.postgres` — Postgres settings
  - `env/.env.certbot` — Domain/email used for certificate issuance
  - `env/.env.overlay` — Optional user overrides applied during setup

Internally, these are rendered from a template (`env/vars.yaml`) by setup.

---

## Instance naming and volumes

- `DN8NH_INSTANCE_NAME` controls the prefix for external Docker volumes.
  - Example volume names:
    - `${DN8NH_INSTANCE_NAME}_n8n_data`
    - `${DN8NH_INSTANCE_NAME}_n8n_files`
    - `${DN8NH_INSTANCE_NAME}_n8n-postgres_data`
    - `${DN8NH_INSTANCE_NAME}_n8n-certbot-etc`
- `COMPOSE_PROJECT_NAME` affects container and network names (defaults to the instance name).

## Where certificates live

- Certificates are stored in the Docker volume `${DN8NH_INSTANCE_NAME}_n8n-certbot-etc`.
- Mounted in containers at `/etc/letsencrypt`.
- Live certs for your domain:
  - `/etc/letsencrypt/live/$N8N_HOST/fullchain.pem`
  - `/etc/letsencrypt/live/$N8N_HOST/privkey.pem`

---

## Customization tips

- Use `env/.env.overlay` for quick overrides without editing generated files.
- For advanced n8n/Postgres options, extend `env/.env.n8n` and `env/.env.postgres` accordingly.

---

For operational details, see [OPERATIONS.md](OPERATIONS.md).
