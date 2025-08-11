# Configuration Reference: Hardened n8n Docker Stack

This document explains all environment variables and configuration options used in the stack.

---

## .env File Variables

| Variable                  | Description                                              | Example / Default         |
|---------------------------|----------------------------------------------------------|---------------------------|
| N8N_HOST                  | Public domain name for your n8n instance                 | n8n.example.com           |
| N8N_PROTOCOL              | Protocol for n8n (should be 'https')                     | https                    |
| N8N_PORT                  | Port for n8n internal service                            | 5678                     |
| N8N_ENCRYPTION_KEY        | Key for encrypting credentials/secrets in n8n            | (auto-generated)          |
| N8N_BASIC_AUTH_ACTIVE     | Enable basic auth for n8n UI/API                         | true                     |
| N8N_BASIC_AUTH_USER       | Username for basic auth                                  | admin                    |
| N8N_BASIC_AUTH_PASSWORD   | Password for basic auth                                  | (auto-generated)          |
| POSTGRES_DB               | Database name for n8n                                    | n8n                      |
| POSTGRES_USER             | Database user                                            | n8n                      |
| POSTGRES_PASSWORD         | Database password                                        | (auto-generated)          |
| LETSENCRYPT_EMAIL         | Email for Let's Encrypt notifications                    | user@example.com          |
| GENERIC_TIMEZONE          | Timezone for containers                                  | America/New_York          |
| N8N_USER_HOME_DIRECTORY   | Home dir for n8n user data                               | /home/node/.n8n           |
| N8N_EDITOR_BASE_URL       | Public URL for n8n editor (if needed)                    | https://n8n.example.com   |
| N8N_WEBHOOK_TUNNEL_URL    | Public URL for webhooks (if needed)                      | (optional)                |

---

## Docker Compose Service Configs

- **Volumes**: See [ARCHITECTURE.md](ARCHITECTURE.md) for details on what each volume stores.
- **Networks**: `n8n-network` (main), `cert-net` (certbot/acme only)
- **Healthchecks**: Each service defines a healthcheck for robust orchestration.

---

## Nginx Configuration

- Generated from `nginx-https.conf.template` using `envsubst` with your domain.
- SSL certificates are stored in `/etc/letsencrypt` (read-only for nginx).

---

## Customization Tips

- You may add more environment variables or override defaults in `.env` as needed.
- For advanced n8n or Postgres options, consult upstream docs and extend your `.env` accordingly.

---

For operational details, see [OPERATIONS.md](OPERATIONS.md).
