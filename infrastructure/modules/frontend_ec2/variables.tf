variable "app_name" {
  type        = string
  description = "Nom de l'application"
}

variable "environment" {
  type        = string
  description = "Environnement (dev / prod)"
}

variable "vpc_id" {
  type        = string
  description = "ID du VPC"
}

variable "public_subnet_id" {
  type        = string
  description = "ID du subnet PUBLIC AZ-A pour l'instance frontend"
}

variable "sg_frontend_id" {
  type        = string
  description = "ID du Security Group frontend (port 80 internet + port 22 debug)"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Type d'instance EC2 frontend (t3.micro pour AWS Academy)"
}

variable "frontend_image" {
  type        = string
  description = "Image Docker Hub frontend (ex: yassinetanabene/shopvault-frontend:latest)"
}

variable "alb_dns_name" {
  type        = string
  description = "DNS de l'ALB backend - le frontend communique UNIQUEMENT via ce DNS (jamais IP directe)"
}

variable "next_public_stripe_publishable_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Cle publique Stripe pour le frontend (NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY)"
}

variable "dockerhub_username" {
  type        = string
  description = "Nom d'utilisateur Docker Hub pour docker pull"
}

variable "dockerhub_token" {
  type        = string
  sensitive   = true
  description = "Token Docker Hub pour docker pull"
}
