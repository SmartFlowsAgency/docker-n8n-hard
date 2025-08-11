# Project Roadmap: Hardened n8n Docker Stack        

This roadmap outlines planned features, improvements, and logical next steps for the project. Contributions and suggestions are welcome!

## Near-Term Goals
- **Analyze logs with free calls to groq**
- **Gracefully downgrade n8n to old version**
- **Detect startup status and remove manual initialization**
- **Improve cleanup for docker-compose down**
- **Expand Logging and Monitoring capabilities**

## Next Steps
- **Automated monitoring and alerting integration** (e.g., Prometheus/Grafana, email/webhook alerts)
- **Multi-environment (dev/stage/prod) deployment profiles**

## Testing Goals
- Automated integration tests for `dn8nh.sh` and operational scripts
- Continuous Integration (CI) for Docker Compose health and service readiness
- Security regression testing for container hardening and permissions

## Future Ideas
- User-friendly web UI for stack management
- Optional SSO/OAuth2 integration
- Automated offsite backup scheduling
- Advanced workflow versioning support

---

*Last updated: 2025-07-26*