# Operations & Maintenance: Hardened n8n Docker Stack

This guide covers day-to-day operations, backup/restore, updates, SSL renewal, and troubleshooting for your deployment.

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

---

## 2. Backup & Restore

- **Backup:**
  ```sh
  ./dn8nh.sh backup
  ```
  - Creates a compressed archive of PostgreSQL and n8n data volumes.
  - Store backups securely and test restores regularly.

- **Restore:**
  - Manual process: Stop the stack, restore backup files to the appropriate Docker volumes, then redeploy.
  - (Optional: Provide a restore script for automation.)

---

## 3. Updating the Stack

- **Update images:**
  ```sh
  docker-compose pull
  ./dn8nh.sh build
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
- **Automatic renewal:**
  - Certbot is scheduled to renew certificates automatically via cron inside the container.
  - Monitor certificate expiry and logs for errors.

---

## 5. Troubleshooting

- **Common issues:**
  - Permissions errors: Ensure `permissions-init` runs and all scripts are executable.
  - SSL errors: Check DNS, ensure port 80/443 are open, verify domain points to server.
  - Service health: Use `./dn8nh.sh logs` and Docker healthchecks to diagnose.
- **Check service status:**
  ```sh
  docker-compose ps
  ```
- **Check container logs:**
  ```sh
  docker-compose logs <service>
  ```

---

## 6. Best Practices

- Regularly update Docker images and run security updates on the host.
- Store `.env` and backups securely (off-server if possible).
- Monitor disk usage and prune unused Docker resources.
- Review logs for anomalies and failed healthchecks.

---

## 7. Security Incident Response

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
   docker-compose down
   docker-compose up -d
   ```
4. **Restore from backup:**
   ```bash
   # Stop services
   docker-compose down

   # Restore data
   tar -xzf n8n_backup_YYYYMMDD.tar.gz

   # Restart services
   docker-compose up -d
   ```
5. **Reset encryption key (if compromised):**
   ```bash
   NEW_KEY=$(openssl rand -base64 32)
   echo "New encryption key: $NEW_KEY"
   sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$NEW_KEY/" .env
   docker-compose restart n8n
   ```

---

## 8. Emergency Contacts
- (Document your incident response team contacts here)

---

For configuration details, see [CONFIGURATION.md](CONFIGURATION.md).
