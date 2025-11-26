# Operations & Maintenance: Hardened n8n Docker Stack

This guide covers day-to-day operations, backup/restore, updates, SSL renewal, and troubleshooting for your deployment.

---

## 0. Initial Setup (first run)

- Prerequisites: Docker and Docker Compose v2 (the `docker compose` CLI).
- Run setup to render envs, ensure volumes, render nginx, and obtain SSL certificates:
  ```sh
  ./dn8nh.sh setup
  ```

---

## 1. Starting & Stopping the Stack

- **Start (deploy):**
  ```sh
  ./dn8nh.sh deploy
  ```
- **Stop:**
  ```sh
  ./dn8nh.sh down
  ```
- **View logs:**
  ```sh
  ./dn8nh.sh logs
  ```

- **Status:**
  ```sh
  ./dn8nh.sh status
  ```

---

## 2. Backup & Restore

- **Backup:**
  ```sh
  ./dn8nh.sh backup
  ```
  - Creates a compressed archive of PostgreSQL and n8n data volumes.
  - Store backups securely and test restores regularly.

- **Restore:**
  - Automated restore using the orchestrator:
    ```sh
    # Restore the latest backups for all volumes and restart services
    ./dn8nh.sh restore --latest --restart
    ```
  - Options:
    - `--from=DIR` Use this directory for backup archives (default: ../backups)
    - `--latest`   Auto-select the latest archive for each resolved volume name
    - `--interactive` Prompt per volume to select an archive (shows recent matches)
    - `--n8n-data-archive=FILE` `--n8n-files-archive=FILE` `--postgres-archive=FILE` `--certs-archive=FILE`
    - `--wipe-before` Wipe existing volume contents before restoring (destructive)
    - `--restart`  Start postgres, n8n, and nginx-rproxy after restore
    - `--dry-run`  Show what would happen without making changes
    - `--print-config` Print resolved volume names and expected archive patterns, then exit
    - `--preserve-certs` Do not restore certificate volume; leave existing certs untouched
  - Restore specific archives:
    ```sh
    ./dn8nh.sh restore --from=./backups \
      production_n8n_data-20250101-010000.tar.gz \
      production_n8n-postgres_data-20250101-010000.tar.gz
    ```
  - Interactive selection:
    ```sh
    ./dn8nh.sh restore --interactive --from=./backups --restart
    ```
  - Per-volume explicit files:
    ```sh
    ./dn8nh.sh restore --from=./backups \
      --n8n-data-archive=myprod_n8n_data-20251101-010000.tar.gz \
      --postgres-archive=myprod_n8n-postgres_data-20251101-010000.tar.gz \
      --restart
    ```
  - Notes:
    - Selection uses the resolved volume names. You can override names via `.env`:
      `N8N_DATA_VOLUME_NAME`, `N8N_FILES_VOLUME_NAME`, `POSTGRES_DATA_VOLUME_NAME`, `CERTBOT_ETC_VOLUME_NAME`.
    - Use `./dn8nh.sh restore --print-config` to see the exact resolved names and expected archive patterns.
    - Services are stopped during restore; nginx is reloaded if certs are restored.

---

## 3. Updating the Stack

- **Update images and redeploy:**
  ```sh
  docker compose pull
  ./dn8nh.sh deploy
  ```
  - **Review CHANGELOG.md** for breaking changes before updating.
  - Always backup before major updates.

---

## 4. SSL Certificate Renewal

- **Manual renewal:**
  ```sh
  ./dn8nh.sh cert-renew
  ```
  - Uses the cert-init profile to run `certbot renew` via webroot and reload nginx.

- **Automatic renewal (optional):**
  - Not enabled by default. You may add a host cron job to run `./dn8nh.sh cert-renew` periodically (e.g., daily).
  - Ensure port 80 is available when the renewal runs.

---

## 5. HTTP-only fallback (temporary)

- For temporary non-SSL access (e.g., before DNS propagates):
  ```sh
  ./dn8nh.sh deploy --http
  ```
- Not recommended for production. Switch to HTTPS once certificates are obtained.

---

## 6. Troubleshooting

- **Common issues:**
  - Permissions errors: Ensure `permissions-init` runs and all scripts are executable.
  - SSL errors: Check DNS, ensure port 80/443 are open, verify domain points to server.
  - Service health: Use `./dn8nh.sh logs` and Docker healthchecks to diagnose.
- **Check service status:**
  ```sh
  ./dn8nh.sh status
  ```
- **Check container logs:**
  ```sh
  docker compose logs <service>
  ```

---

## 7. Best Practices

- Regularly update Docker images and run security updates on the host.
- Store `.env` and backups securely (off-server if possible).
- Monitor disk usage and prune unused Docker resources.
- Review logs for anomalies and failed healthchecks.

---

## 8. Security Incident Response

If you suspect a security incident (compromise, intrusion, or data leak):

### Immediate Actions
1. **Monitor unusual activity:**
   ```bash
   # Check for suspicious IPs
   tail -n 1000 logs/nginx/access.log | grep -E "(401|403|404)" | awk '{print $1}' | sort | uniq -c | sort -nr

   # Check for brute force attempts
   grep "401" logs/nginx/access.log | tail -50
   ```
2. **Block malicious IPs:**
   ```bash
   # Temporarily block an IP
   sudo ufw insert 1 deny from MALICIOUS_IP

   # Or use iptables
   sudo iptables -A INPUT -s MALICIOUS_IP -j DROP
   ```
3. **Change credentials immediately:**
   - Update `.env` with new passwords and keys.
   - Restart containers:
   ```bash
   docker compose down
   docker compose up -d
   ```
4. **Restore from backup:**
   ```bash
   # Stop services
   docker compose down

   # Restore data
   tar -xzf n8n_backup_YYYYMMDD.tar.gz

   # Restart services
   docker compose up -d
   ```
5. **Reset encryption key (if compromised):**
   ```bash
   NEW_KEY=$(openssl rand -base64 32)
   echo "New encryption key: $NEW_KEY"
   sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$NEW_KEY/" .env
   docker compose restart n8n
   ```

---

## 9. Emergency Contacts
- (Document your incident response team contacts here)

---

For configuration details, see [CONFIGURATION.md](CONFIGURATION.md).
