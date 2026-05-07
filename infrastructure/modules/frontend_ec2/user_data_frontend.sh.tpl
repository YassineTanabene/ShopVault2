#!/bin/bash
# =============================================================================
# USER DATA — EC2 Frontend (subnet public)
# Exigence prof : nginx reverse-proxy port 80 -> 3000 + docker pull image frontend
# Le frontend communique UNIQUEMENT avec le DNS de l'ALB backend
# JAMAIS via l'IP directe d'une instance EC2 backend
# =============================================================================

set -e
exec > /var/log/user-data.log 2>&1

echo "======================================================="
echo " ShopVault Frontend — User Data Start"
echo " $(date)"
echo "======================================================="

# -----------------------------------------------------------------------------
# 1. Mise a jour systeme et installation dependances
# -----------------------------------------------------------------------------
apt-get update -y
apt-get install -y \
  docker.io \
  nginx \
  curl \
  jq

# Demarrer et activer Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

echo "[OK] Docker et nginx installes"

# -----------------------------------------------------------------------------
# 2. Login Docker Hub
# -----------------------------------------------------------------------------
echo "${dockerhub_token}" | docker login \
  --username "${dockerhub_username}" \
  --password-stdin

echo "[OK] Docker Hub login reussi"

# -----------------------------------------------------------------------------
# 3. Pull de l'image frontend depuis Docker Hub
# -----------------------------------------------------------------------------
docker pull ${frontend_image}

echo "[OK] Image frontend pullee : ${frontend_image}"

# -----------------------------------------------------------------------------
# 4. Configuration nginx — reverse proxy port 80 -> localhost:3000
# Exigence prof : le frontend Next.js tourne sur port 3000
# nginx ecoute sur port 80 et forward vers 3000
# -----------------------------------------------------------------------------
cat > /etc/nginx/sites-available/frontend << 'NGINX_CONF'
server {
    listen 80;
    server_name _;

    # Health check nginx
    location /nginx-health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }

    # Proxy vers le conteneur Next.js (port 3000)
    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
NGINX_CONF

# Activer le site et desactiver le site par defaut
ln -sf /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled/frontend
rm -f /etc/nginx/sites-enabled/default

# Tester et recharger nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "[OK] nginx configure et demarre (port 80 -> 3000)"

# -----------------------------------------------------------------------------
# 5. Demarrage du conteneur frontend
# NEXT_PUBLIC_API_URL = DNS de l'ALB backend (exigence prof : jamais IP directe)
# INTERNAL_API_URL = pour le SSR (server-side rendering) Next.js
# --restart always : redemarrage automatique si crash ou reboot EC2
# -----------------------------------------------------------------------------
ALB_URL="http://${alb_dns_name}"

docker run -d \
  --name frontend \
  --restart always \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e PORT=3000 \
  -e HOSTNAME="0.0.0.0" \
  -e NEXT_PUBLIC_API_URL="$ALB_URL" \
  -e INTERNAL_API_URL="$ALB_URL" \
  -e NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY="${next_public_stripe_publishable_key}" \
  ${frontend_image}

echo "[OK] Conteneur frontend demarre sur port 3000"
echo "[OK] NEXT_PUBLIC_API_URL = $ALB_URL"

# -----------------------------------------------------------------------------
# 6. Health check loop — attendre que le frontend soit pret
# -----------------------------------------------------------------------------
echo "[INFO] Attente health check frontend..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    echo "[OK] Frontend healthy apres $${i} tentative(s)"
    break
  fi
  echo "[INFO] Tentative $${i}/30 - frontend pas encore pret, attente 10s..."
  sleep 10
done

# Verifier que nginx proxy fonctionne
echo "[INFO] Verification du proxy nginx..."
if curl -sf http://localhost:80 > /dev/null 2>&1; then
  echo "[OK] Proxy nginx operationnel (port 80 -> 3000)"
else
  echo "[WARN] Proxy nginx pas encore operationnel, verifier les logs nginx"
fi

echo "======================================================="
echo " ShopVault Frontend — User Data Complete"
echo " $(date)"
echo " Frontend disponible sur : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "======================================================="
