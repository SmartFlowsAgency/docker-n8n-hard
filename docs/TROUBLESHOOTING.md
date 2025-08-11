# Quick Troubleshooting Table

| Problem / Error                 | Likely Cause / Fix                                                                 |
|---------------------------------|-----------------------------------------------------------------------------------|
| Permission denied on volume     | Run `./dn8nh.sh setup` and `deploy` to fix permissions.                          |
| n8n or Postgres not healthy     | Check Docker logs with `./dn8nh.sh logs` and ensure .env is correct.             |
| SSL certificate not issued      | Make sure your domain points to this server and ports 80/443 are open.            |
| Certbot fails, renewal error    | Check DNS, firewall, and that certbot containers can write to certbot-etc volume. |
| Web UI not accessible           | Check that `nginx-stark` and `n8n` are healthy; verify domain and SSL.            |
| Backup fails                    | Ensure enough disk space and correct permissions on backup target.                |
| Docker Compose version error    | Install Docker Compose v2+ or use `docker compose` command.                       |
| .env file missing/invalid       | Run `./dn8nh.sh setup` to (re)generate.                                          |
| Changes to .env not applied     | Run `./dn8nh.sh build` then `./dn8nh.sh deploy` after editing .env.             |
| Healthcheck fails               | See logs for service, check configs, and verify all dependencies are healthy.     |

For more details, see [OPERATIONS.md](OPERATIONS.md) and [SECURITY.md](SECURITY.md).
