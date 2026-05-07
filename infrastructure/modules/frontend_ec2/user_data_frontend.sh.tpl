#!/bin/bash
# =============================================================================
# USER DATA — EC2 Frontend (subnet public)
# Exigence prof : nginx reverse-proxy port 80 -> 3000 + docker pull image frontend
# Le frontend communique UNIQUEMENT avec le DNS de l'ALB backend
# JAMAIS via l'IP directe d'une instance EC2 backend
#
# ARCHITECTURE DES APPELS API :
#   Browser → GET/POST /api/* (URL relative)
#     → nginx port 80
#       → /api/* : proxy_pass vers ALB backend (http://${alb_dns_name})
#       → /*     : proxy_pass vers Next.js (localhost:3000)
#
# NOTE : NEXT_PUBLIC_API_URL est vide au build (baked dans le bundle JS).
# Le client Next.js fait des appels relatifs /api/... intentionnellement.
# Nginx joue le role de "API gateway" pour le frontend.
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
# 4. Configuration nginx — double responsabilite :
#    a) /api/* et /health → proxy vers l'ALB backend (port 80)
#    b) /*               → proxy vers Next.js (localhost:3000)
#
# POURQUOI : NEXT_PUBLIC_API_URL est vide au build (baked dans le JS bundle).
# Le browser fait des appels relatifs (/api/auth/register).
# Nginx intercepte /api/* et les forward vers l'ALB backend.
# C'est la seule correction sans modifier le code frontend.
# -----------------------------------------------------------------------------
ALB_URL="http://${alb_dns_name}"

cat > /etc/nginx/sites-available/frontend << NGINX_CONF
server {
    listen 80;
    server_name _;

    # ------------------------------------------------------------------
    # Health check nginx (pour debug)
    # ------------------------------------------------------------------
    location /nginx-health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }

    # ------------------------------------------------------------------
    # CRITIQUE : proxy /api/* vers l'ALB backend
    # Le browser Next.js fait des appels relatifs /api/...
    # Nginx les intercepte et les forward vers le backend via l'ALB
    # ------------------------------------------------------------------
    location /api/ {
        proxy_pass         $ALB_URL/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
        proxy_connect_timeout 10s;
    }

    # ------------------------------------------------------------------
    # Health check backend (accessible depuis internet pour debug)
    # ------------------------------------------------------------------
    location = /health {
        proxy_pass         $ALB_URL/health;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_read_timeout 10s;
    }

    # ------------------------------------------------------------------
    # Tout le reste -> Next.js (localhost:3000)
    # ------------------------------------------------------------------
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

# Activer le site et desactiver le site par defaut
ln -sf /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled/frontend
rm -f /etc/nginx/sites-enabled/default

# Tester et recharger nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "[OK] nginx configure : /api/* -> ALB ($ALB_URL), /* -> Next.js :3000"

# -----------------------------------------------------------------------------
# 5. Demarrage du conteneur frontend
# INTERNAL_API_URL : utilise par Next.js cote serveur (SSR) pour les appels API
# NEXT_PUBLIC_API_URL : vide intentionnellement (le browser fait des appels
#                       relatifs /api/* interceptes par nginx -> ALB)
# --restart always : redemarrage automatique si crash ou reboot EC2
# -----------------------------------------------------------------------------
docker run -d \
  --name frontend \
  --restart always \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e PORT=3000 \
  -e HOSTNAME="0.0.0.0" \
  -e INTERNAL_API_URL="$ALB_URL" \
  -e NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY="${next_public_stripe_publishable_key}" \
  ${frontend_image}

echo "[OK] Conteneur frontend demarre sur port 3000"
echo "[OK] INTERNAL_API_URL (SSR) = $ALB_URL"
echo "[OK] Appels client /api/* interceptes par nginx et proxyifies vers $ALB_URL"

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

# Verifier que le proxy nginx /api/ fonctionne
echo "[INFO] Verification du proxy nginx /api/ vers ALB..."
if curl -sf "$ALB_URL/health" > /dev/null 2>&1; then
  echo "[OK] ALB backend accessible depuis le frontend EC2"
else
  echo "[WARN] ALB backend pas encore accessible, verifier les SGs et le health check"
fi

echo "======================================================="
echo " ShopVault Frontend — User Data Complete"
echo " $(date)"
echo " Frontend : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo " API proxy : /* -> :3000, /api/* -> $ALB_URL"
echo "======================================================="
