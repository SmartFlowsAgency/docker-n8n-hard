# Deployment Recommendations for Dockerized n8n + NGINX + Let's Encrypt

## SELinux/AppArmor
**NOTE:** SELinux and AppArmor are NOT issues for this deployment. All permission problems are unrelated to host-level security modules.

## Key Recommendations

1. **Consistent UID/GID**
   - All containers that need to access SSL certificates (nginx, certbot) must run as the same user and group (recommended: UID 1500, GID 1500).
   - Ensure Docker Compose and any scripts use this UID/GID consistently.

2. **Volume Permissions**
   - Docker creates directories as `root:root` with `700` permissions by default. This blocks non-root users from traversing directories.
   - Always run BOTH `chown -R 1500:1500 /etc/letsencrypt` AND `find /etc/letsencrypt -type d -exec chmod 755 {} \;` (plus `chmod 644` for files) before starting nginx or certbot.
   - Fix permissions for all directories in the chain, including symlink targets in `/etc/letsencrypt/live` and `/etc/letsencrypt/archive`.

3. **Service Ordering**
   - Ensure that `certbot-init` (or any permission-fixing container) completes before nginx or certbot containers start.
   - Use Docker Compose `depends_on` and/or healthchecks to enforce this order.

4. **Symlink Handling**
   - Certificate files in `/etc/letsencrypt/live/<domain>/` are symlinks to `/etc/letsencrypt/archive/<domain>/`. Permissions must be correct on both source and target directories.

5. **Scripts and Automation**
   - Always use the provided deployment scripts (`deploy.sh`, `deploy-production.sh`, etc.) to ensure permissions are fixed before containers start.
   - Avoid starting containers manually.

6. **Security Options**
   - Harden containers with `read_only: true`, `cap_drop`, and `security_opt`, but ensure these settings do not block required functionality (e.g., writing logs or certs).

7. **Race Conditions**
   - If nginx starts before permissions are fixed, it will fail. Consider entrypoint scripts or service dependencies to avoid this.

8. **Testing**
   - Use included test scripts (e.g., `test-permissions.sh`, `test-simple.sh`) to verify certificate access as UID 1500 before starting nginx in production.

## Troubleshooting
- If nginx cannot read certificate files, it is almost always a permissions or service ordering issue, NOT a host security module issue.
- Double-check UID/GID, directory permissions, and service startup order.

---

**Summary:**
- All permission errors are due to Docker volume ownership/mode and container user mismatch, NOT SELinux/AppArmor.
- Fix permissions and enforce correct service order for reliable, secure operation.
