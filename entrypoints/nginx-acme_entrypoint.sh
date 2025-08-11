#!/usr/bin/env bash
# Set this in one place for all scripts
CERT_PATH="/etc/letsencrypt/live/n8n.smartflows.agency/fullchain.pem"

nginx
while [ ! -f "$CERT_PATH" ]; do
  sleep 2
done
echo "Certificate detected, stopping nginx-acme."
nginx -s quit