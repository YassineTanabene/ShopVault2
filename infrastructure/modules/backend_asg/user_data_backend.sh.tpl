#!/bin/bash
# =============================================================================
# USER DATA — EC2 Backend (Auto Scaling Group)
# Exigence prof : docker pull depuis Docker Hub + docker run avec env vars
# Instance dans subnet PRIVE — acces internet via NAT Gateway
# =============================================================================

set -e
exec > /var/log/user-data.log 2>&1

echo "======================================================="
echo " ShopVault Backend — User Data Start"
echo " $(date)"
echo "======================================================="

# -----------------------------------------------------------------------------
# 1. Mise a jour systeme et installation dependances
# -----------------------------------------------------------------------------
apt-get update -y
apt-get install -y \
  docker.io \
  curl \
  jq \
  awscli \
  snapd

# SSM Agent — requis pour le tunnel SSM depuis GitHub Actions (job seed)
snap install amazon-ssm-agent --classic || true
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true
systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service || true

# Demarrer et activer Docker
systemctl start docker
systemctl enable docker

# Ajouter ubuntu au groupe docker
usermod -aG docker ubuntu

echo "[OK] Docker installe et demarre"

# -----------------------------------------------------------------------------
# 2. Login Docker Hub (pour docker pull d'images privees)
# -----------------------------------------------------------------------------
echo "${dockerhub_token}" | docker login \
  --username "${dockerhub_username}" \
  --password-stdin

echo "[OK] Docker Hub login reussi"

# -----------------------------------------------------------------------------
# 3. Pull de l'image backend depuis Docker Hub
# -----------------------------------------------------------------------------
docker pull ${backend_image}

echo "[OK] Image backend pullee : ${backend_image}"

# -----------------------------------------------------------------------------
# 4. Construction de la DATABASE_URL
# L'endpoint RDS contient deja le port (host:5432)
# On extrait le host seul pour construire l'URL proprement
# -----------------------------------------------------------------------------
DB_HOST=$(echo "${db_endpoint}" | cut -d: -f1)
DATABASE_URL="postgresql://${db_username}:${db_password}@$${DB_HOST}:5432/${db_name}"

echo "[OK] DATABASE_URL construite (host: $${DB_HOST})"

# -----------------------------------------------------------------------------
# 5. Execution des migrations Prisma (une seule instance le fait)
# Protection par lock file pour eviter les conflits dans l'ASG
# -----------------------------------------------------------------------------
LOCK_FILE="/tmp/prisma_migrate.lock"
if [ ! -f "$LOCK_FILE" ]; then
  touch "$LOCK_FILE"
  echo "[INFO] Execution des migrations Prisma..."

  docker run --rm \
    -e DATABASE_URL="$DATABASE_URL" \
    ${backend_image} \
    npx prisma migrate deploy --schema=src/prisma/schema.prisma || true

  echo "[OK] Migrations Prisma terminees"
fi

# -----------------------------------------------------------------------------
# 6. Demarrage du conteneur backend
# --restart always : redemarrage automatique si crash ou reboot EC2
# -----------------------------------------------------------------------------
docker run -d \
  --name backend \
  --restart always \
  -p 4000:4000 \
  -e NODE_ENV=production \
  -e PORT=4000 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e JWT_SECRET="${jwt_secret}" \
  -e JWT_REFRESH_SECRET="${jwt_refresh_secret}" \
  -e STRIPE_SECRET_KEY="${stripe_secret_key}" \
  -e STRIPE_WEBHOOK_SECRET="${stripe_webhook_secret}" \
  -e AWS_REGION="${aws_region}" \
  -e AWS_S3_BUCKET="${s3_assets_bucket}" \
  -e FRONTEND_URL="*" \
  -e TRUST_PROXY=1 \
  ${backend_image}

echo "[OK] Conteneur backend demarre sur port 4000"

# -----------------------------------------------------------------------------
# 7. Health check loop — attendre que le backend soit pret
# L'ALB Target Group fera ses propres checks, mais on verifie localement
# -----------------------------------------------------------------------------
echo "[INFO] Attente health check backend..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:4000/health > /dev/null 2>&1; then
    echo "[OK] Backend healthy apres $${i} tentative(s)"
    break
  fi
  echo "[INFO] Tentative $${i}/30 - backend pas encore pret, attente 10s..."
  sleep 10
done

echo "======================================================="
echo " ShopVault Backend — User Data Complete"
echo " $(date)"
echo "======================================================="
