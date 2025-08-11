# Security Model & Hardening: Hardened n8n Docker Stack

This document details the security strategies, container hardening, and permission flows implemented in this deployment.

---

## 1. Container Hardening

- **Read-only root filesystems**: All containers except those that must write (e.g., postgres, certbot) run with `read_only: true`.
- **Dropped Linux capabilities**: All containers drop `ALL` capabilities, adding back only what is strictly required (e.g., `NET_BIND_SERVICE`, `CHOWN`, `FOWNER`, `SETUID`, `SETGID`).
- **no-new-privileges**: All containers use `security_opt: no-new-privileges:true` to prevent privilege escalation.
- **tmpfs mounts**: Writable directories (e.g., `/tmp`, `/var/tmp`, `.npm`, `.cache`) are mounted as `tmpfs` with `noexec,nosuid`.
- **SELinux-compatible volumes**: Volumes are labeled for compatibility with SELinux and other MAC systems.

---

## 2. Permissions Initialization

- **permissions-init**: A dedicated init container runs before any other service to set correct ownership and permissions on all Docker volumes. This avoids permission errors in hardened containers.
- **Entrypoint scripts**: Custom entrypoints for postgres, certbot, and nginx ensure runtime permissions are correct without running containers as root.

---

## 3. Least Privilege Principle

- **Non-root users**: Application containers (n8n, nginx, postgres) run as non-root users with only the minimum required privileges.
- **Minimal volume access**: Volumes are mounted read-only wherever possible; only the owning service has write access.
- **Network segmentation**: Separate Docker networks for certificate management and main application traffic.

---

## 4. Secrets & Sensitive Data

- **.env file**: All secrets (DB password, n8n encryption key, basic auth) are stored in `.env` and injected into containers as environment variables.
- **File permissions**: `.env` is generated with strict permissions and should be kept secure and backed up.

---

## 5. SSL/TLS Management

- **Automated Certbot**: SSL certificates are obtained and renewed automatically using isolated containers and ACME HTTP-01 challenges.
- **Nginx**: Serves as the SSL termination point with strict config, only reading certificates from a read-only volume.

---

## 6. Monitoring & Health

- **Healthchecks**: All critical services (nginx, n8n, postgres) have healthchecks defined in Compose to ensure only healthy containers are exposed.
- **Logs**: Nginx and application logs are stored in dedicated volumes with correct permissions.

---

## 7. Security Trade-offs & Considerations

- Some capabilities (e.g., `DAC_OVERRIDE` for postgres, `SETUID/SETGID` for nginx) are required for correct operation.
- All scripts and entrypoints are reviewed for minimal privilege and safe execution.
- Regularly update Docker images and review logs for anomalies.

---

## Security Checklist

### Pre-deployment
- [ ] Changed all default passwords
- [ ] Generated strong encryption key
- [ ] Configured proper SSL certificates
- [ ] Hardened Docker Compose and images
- [ ] Set up firewall (e.g., ufw)
- [ ] Restricted SSH access
- [ ] Set up monitoring/alerting

### Post-deployment
- [ ] Verified SSL is working
- [ ] Tested authentication and access controls
- [ ] Checked logs for suspicious activity
- [ ] Performed backup and restore test
- [ ] Enabled automatic updates
- [ ] Reviewed security headers

---

For operational details, see [OPERATIONS.md](OPERATIONS.md).

---

## Security Tools & Resources

- [SSL Labs](https://www.ssllabs.com/ssltest/) - Test your SSL config
- [Security Headers](https://securityheaders.com/) - Analyze security headers
- [Shodan](https://www.shodan.io/) - Monitor your server's exposure
