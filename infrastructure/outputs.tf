# =============================================================================
# Outputs globaux — architecture cible conforme aux exigences professeur
# Affiches dans les logs CI/CD apres terraform apply
# =============================================================================

# -----------------------------------------------------------------------------
# ALB Backend — URL principale de l'API
# Le frontend communique UNIQUEMENT via ce DNS
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS public de l'ALB backend — http://<alb_dns>/health pour verifier"
  value       = module.alb.alb_dns_name
}

# -----------------------------------------------------------------------------
# Frontend EC2 — IP publique accessible depuis internet
# -----------------------------------------------------------------------------
output "frontend_public_ip" {
  description = "IP publique de l'instance EC2 Frontend — http://<ip> pour acceder au site"
  value       = module.frontend_ec2.public_ip
}

output "frontend_public_dns" {
  description = "DNS public de l'instance EC2 Frontend"
  value       = module.frontend_ec2.public_dns
}

# -----------------------------------------------------------------------------
# RDS — endpoint de connexion (sensible)
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint RDS PostgreSQL (host:port) — sensible"
  value       = module.rds.db_endpoint
  sensitive   = true
}

# -----------------------------------------------------------------------------
# S3 — noms des buckets
# -----------------------------------------------------------------------------
output "assets_bucket_name" {
  description = "Nom du bucket S3 pour les images produits"
  value       = module.s3.assets_bucket_name
}

output "static_bucket_name" {
  description = "Nom du bucket S3 pour les assets statiques"
  value       = module.s3.static_bucket_name
}

# -----------------------------------------------------------------------------
# ASG — nom pour verification dans la console AWS
# -----------------------------------------------------------------------------
output "backend_asg_name" {
  description = "Nom de l'Auto Scaling Group backend — verifiable dans la console EC2"
  value       = module.backend_asg.asg_name
}

# -----------------------------------------------------------------------------
# CloudFront (commente — non requis par le professeur)
# -----------------------------------------------------------------------------
# output "cloudfront_domain" {
#   description = "Domaine CloudFront (optionnel)"
#   value       = module.cloudfront.frontend_distribution_domain
# }