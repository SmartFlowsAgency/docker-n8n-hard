#!/usr/bin/env bash
set -e

echo "Setting up directory permissions..."

# PostgreSQL data (postgres:15-alpine uses UID/GID 999)
mkdir -p /postgres-data
chown -R 999:999 /postgres-data
chmod -R 700 /postgres-data
echo "✓ PostgreSQL permissions set"

# N8N data (n8nio/n8n uses UID/GID 1000 - node user)
mkdir -p /n8n-data /n8n-files
chown -R 1000:1000 /n8n-data /n8n-files
chmod 755 /n8n-data /n8n-files
echo "✓ N8N permissions set"

# Certbot directories (certbot runs as root but nginx needs read access)
mkdir -p /certbot-etc /certbot-www
chown -R 0:0 /certbot-etc /certbot-www
chmod 755 /certbot-etc /certbot-www
find /certbot-etc -type d -exec chmod 755 {} \;
find /certbot-etc -type f -exec chmod 644 {} \;
echo "✓ Certbot permissions set"

# Nginx logs (nginx:alpine uses UID/GID 101:101)
mkdir -p /nginx-logs
chown -R 101:101 /nginx-logs
chmod 755 /nginx-logs
echo "✓ Nginx permissions set"

echo "All permissions configured successfully!"