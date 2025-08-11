events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name ${LETSENCRYPT_DOMAIN};

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # ACME challenge for Let's Encrypt
        location /.well-known/acme-challenge/ {
            root /var/www/certbot/;
            try_files $uri =404;
        }

        # Temporary location for initial setup
        location / {
            return 200 "n8n is starting up...";
            add_header Content-Type text/plain;
        }
    }
}