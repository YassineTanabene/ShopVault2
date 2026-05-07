# =============================================================================
# dev.tfvars — Variables d'environnement DEV
# Conforme exigences academiques (ING 2 Cloud Computing)
# ⚠️ ATTENTION : Ne jamais commiter ce fichier avec de vraies credentials !
# Les secrets sont injectes depuis GitHub Actions Secrets en CI/CD.
# =============================================================================

# --- General ------------------------------------------------------------------
environment = "dev"
aws_region  = "us-east-1"
app_name    = "ecommerce"

# --- Base de donnees ----------------------------------------------------------
db_name     = "ecommerce_dev"
db_username = "ecommerceadmin"
# db_password = injected via TF_VAR_db_password from GitHub Secret DB_PASSWORD

# --- Images Docker Hub --------------------------------------------------------
# Format : <dockerhub_username>/<image_name>:<tag>
backend_image  = "yassinetanabene/shopvault-backend:latest"
frontend_image = "yassinetanabene/shopvault-frontend:latest"

# --- Docker Hub ---------------------------------------------------------------
dockerhub_username = "yassinetanabene"
# dockerhub_token = injected via TF_VAR_dockerhub_token from GitHub Secret DOCKERHUB_TOKEN

# --- Types d'instances EC2 (t3.micro pour AWS Academy) -----------------------
backend_instance_type  = "t3.micro"
frontend_instance_type = "t3.micro"

# --- Secrets applicatifs (injectes depuis GitHub Secrets en CI/CD) -----------
# jwt_secret                         = injected via TF_VAR_jwt_secret
# jwt_refresh_secret                 = injected via TF_VAR_jwt_refresh_secret
# stripe_secret_key                  = injected via TF_VAR_stripe_secret_key
# stripe_webhook_secret              = injected via TF_VAR_stripe_webhook_secret
# next_public_stripe_publishable_key = injected via TF_VAR_next_public_stripe_publishable_key