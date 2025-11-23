# n8n Hardened Artifact — User Guide

This guide is for users of the release artifact. It covers the basic workflow and links to deeper docs.

---

## Quickstart

- Prereqs
  - Docker + Docker Compose
  - A domain pointing to this host (A/AAAA record)

- Setup (installs and obtains SSL)
  ```sh
  ./dn8nh.sh setup
  ```

- Deploy (start services in correct order with health checks)
  ```sh
  ./dn8nh.sh deploy
  ```

- Status
  ```sh
  ./dn8nh.sh status
  ```

---

## Configuration

- See docs/CONFIGURATION.md for environment variables and instance naming.
- Minimum required: domain (N8N_HOST or LETSENCRYPT_DOMAIN) and email (LETSENCRYPT_EMAIL).

## Operations

- See docs/OPERATIONS.md for: cert-init, cert-renew, backup, clean, down/up, HTTP-only fallback.

## Commands Reference

- See docs/SCRIPTS.md for user-facing commands.

---

## Support

- See docs/TROUBLESHOOTING.md for common issues: DNS/ACME, port 80 conflicts, health checks.
