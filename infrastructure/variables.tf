# =============================================================================
# Variables globales — infrastructure ShopVault
# Conforme aux exigences academiques (ING 2 Cloud Computing)
# =============================================================================

# -----------------------------------------------------------------------------
# Variables generales
# -----------------------------------------------------------------------------
variable "environment" {
  type        = string
  description = "Environnement de deploiement (dev / prod)"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region AWS"
}

variable "app_name" {
  type        = string
  default     = "ecommerce"
  description = "Prefixe pour toutes les ressources AWS"
}

# -----------------------------------------------------------------------------
# Variables Base de Donnees
# -----------------------------------------------------------------------------
variable "db_name" {
  type        = string
  description = "Nom de la base de donnees PostgreSQL"
}

variable "db_username" {
  type        = string
  description = "Nom d'utilisateur PostgreSQL"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Mot de passe PostgreSQL — injecte via secret GitHub, jamais en dur"
}

# -----------------------------------------------------------------------------
# Variables Docker Hub — images backend et frontend
# -----------------------------------------------------------------------------
variable "backend_image" {
  type        = string
  description = "Image Docker Hub backend (ex: yassinetanabene/shopvault-backend:latest)"
}

variable "frontend_image" {
  type        = string
  description = "Image Docker Hub frontend (ex: yassinetanabene/shopvault-frontend:latest)"
}

variable "dockerhub_username" {
  type        = string
  default     = ""
  description = "Nom d'utilisateur Docker Hub pour docker pull sur les EC2"
}

variable "dockerhub_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Token Docker Hub pour docker pull sur les EC2"
}

# -----------------------------------------------------------------------------
# Variables Application — secrets et configuration
# -----------------------------------------------------------------------------
variable "jwt_secret" {
  type        = string
  sensitive   = true
  description = "Secret JWT access token (min 128 chars hex)"
}

variable "jwt_refresh_secret" {
  type        = string
  sensitive   = true
  description = "Secret JWT refresh token (min 128 chars hex)"
}

variable "stripe_secret_key" {
  type        = string
  sensitive   = true
  description = "Cle secrete Stripe (sk_test_...)"
}

variable "stripe_webhook_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Secret webhook Stripe (whsec_...)"
}

variable "next_public_stripe_publishable_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Cle publique Stripe pour le frontend (pk_test_...)"
}

# -----------------------------------------------------------------------------
# Variables EC2 — types d'instances
# t3.micro recommande pour AWS Academy (compatibilite + cout)
# -----------------------------------------------------------------------------
variable "backend_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Type d'instance EC2 pour les instances backend dans l'ASG"
}

variable "frontend_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Type d'instance EC2 pour l'instance frontend"
}
