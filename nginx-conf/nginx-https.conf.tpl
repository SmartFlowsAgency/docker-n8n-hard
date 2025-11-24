events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn-rs.n8n.io https://ph.n8n.io; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' ws: wss: https://api.n8n.io; frame-ancestors 'self';" always;

    # Security headers for HTTPS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), fullscreen=(self), sync-xhr=()" always;

    # Hide Nginx version
    server_tokens off;

    # Security settings
    client_max_body_size 16M;
    client_body_timeout 10s;
    client_header_timeout 10s;
    keepalive_timeout 5s 5s;
    send_timeout 10s;
    server_names_hash_bucket_size 128;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml+rss;

    # Basic bad bot/user-agent filtering
    #map $http_user_agent $bad_ua {
    #    default 0;
    #    ~*(zgrab|libredtail|l9explore|sqlmap|nikto|dirbuster|wpscan|nmap|acunetix|nessus|masscan|curl|wget) 1;
    #}
#
    # Rate limiting zones
    limit_req_zone  $binary_remote_addr zone=login:10m rate=5r/s;
    limit_req_zone  $binary_remote_addr zone=api:10m rate=10r/s;
    limit_conn_zone  $binary_remote_addr zone=conn_limit_per_ip:10m;
    # Generic rate limiting zone for all requests
    #limit_req_zone  $binary_remote_addr zone=generic:10m rate=30r/m;

    # Upstream for n8n
    upstream n8n {
        server n8n:5678;
    }

    # HTTP server for ACME challenge and redirect
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
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }

        # Redirect all other HTTP traffic to HTTPS
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl;
        http2 on;
        server_name ${LETSENCRYPT_DOMAIN};

        # SSL configuration - Let's Encrypt certificates
        ssl_certificate /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem;

        # Modern SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;
        ssl_session_tickets off;
        ssl_stapling on;
        ssl_stapling_verify on;

        # OCSP stapling
        ssl_trusted_certificate /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/chain.pem;
        resolver 8.8.8.8 8.8.4.4 valid=300s;
        resolver_timeout 5s;

        # Connection limits
        limit_conn conn_limit_per_ip 50;

        # Block obvious bad user-agents
        # if ($bad_ua) { return 403; }

        # Block common attack patterns
        location ~* \.(aspx|php|jsp|cgi)$ {
            return 444;
        }

        # Block access to hidden files
        location ~ /\. {
            deny all;
            access_log off;
            log_not_found off;
        }

        # Explicitly block environment and VCS files
        # location ~* (^|/)\.(env(\..*)?|git|svn|hg|DS_Store|htaccess|htpasswd)$ {
        #     deny all;
        #     access_log off;
        #     log_not_found off;
        # }

        # Block common scanner/probing paths
        location ~* /(actuator|solr|global-protect|phpmyadmin|wp-admin|wp-login\.php|docker-compose.*|geoserver|console|config\.json) {
            return 404;
            access_log off;
            log_not_found off;
        }

        # Main n8n application
        location / {
            # Apply generic rate limiting
            # limit_req zone=generic burst=20 nodelay;
            proxy_pass http://n8n;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            # Proxy timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            # Buffer settings
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
            proxy_busy_buffers_size 8k;
        }

        # WebSocket support for n8n
        location /rest/push {
            proxy_pass http://n8n;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }

        # Rate limiting for authentication
        location ~* ^/(rest|webhook)/(auth|login) {
            limit_req zone=login burst=3 nodelay;
            proxy_pass http://n8n;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
        }

        # Rate limited API endpoint
        location /rest/api {
            limit_req zone=api burst=10 nodelay;
            proxy_pass http://n8n;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Rate limited Webhook endpoints
        location /webhook {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://n8n;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300;
            proxy_send_timeout 300;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
        }
    }
}