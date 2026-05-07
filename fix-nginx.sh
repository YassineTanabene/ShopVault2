#!/bin/bash
# =============================================================================
# PATCH NGINX IMMEDIAT — Fix API proxy /api/* -> ALB backend
# A exécuter en SSH sur le Frontend EC2 : 23.20.182.230
#
# Usage:
#   ssh ubuntu@23.20.182.230
#   bash fix-nginx.sh <ALB_DNS>
#
# Exemple:
#   bash fix-nginx.sh ecommerce-dev-backend-alb-123456789.us-east-1.elb.amazonaws.com
# =============================================================================

ALB_DNS="${1}"

if [ -z "$ALB_DNS" ]; then
  echo "Usage: bash fix-nginx.sh <ALB_DNS>"
  echo "Exemple: bash fix-nginx.sh ecommerce-dev-backend-alb-xxx.us-east-1.elb.amazonaws.com"
  exit 1
fi

echo "[INFO] Patching nginx pour proxifier /api/* vers http://$ALB_DNS"

cat > /etc/nginx/sites-available/frontend << NGINX_CONF
server {
    listen 80;
    server_name _;

    # Health check nginx
    location /nginx-health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }

    # CRITIQUE : proxy /api/* vers le backend via l'ALB
    location /api/ {
        proxy_pass         http://$ALB_DNS/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
        proxy_connect_timeout 10s;
    }

    # Health check backend (debug)
    location = /health {
        proxy_pass         http://$ALB_DNS/health;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_read_timeout 10s;
    }

    # Tout le reste -> Next.js
    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
NGINX_CONF

# Valider la config
nginx -t

if [ $? -eq 0 ]; then
  systemctl reload nginx
  echo ""
  echo "[OK] Nginx recharge avec succes"
  echo "[OK] /api/* -> http://$ALB_DNS/api/"
  echo "[OK] /*     -> localhost:3000"
  echo ""
  echo "[TEST] Health check ALB :"
  curl -s http://$ALB_DNS/health
  echo ""
  echo "[TEST] Proxy nginx /api -> ALB :"
  curl -s http://localhost/health
else
  echo "[ERREUR] Config nginx invalide — non appliquee"
  exit 1
fi
