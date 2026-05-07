variable "app_name" {
  type        = string
  description = "Nom de l'application (préfixe pour tous les ressources)"
}

variable "environment" {
  type        = string
  description = "Environnement de déploiement (dev / prod)"
}

variable "aws_region" {
  type        = string
  description = "Région AWS (ex: us-east-1)"
}
