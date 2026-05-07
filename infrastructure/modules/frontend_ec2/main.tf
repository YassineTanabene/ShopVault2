# =============================================================================
# FRONTEND EC2 — Instance EC2 dedicee dans subnet PUBLIC
# Exigence prof : EC2 dans subnet public, nginx reverse-proxy port 80 -> 3000
# Le frontend communique UNIQUEMENT via le DNS de l'ALB backend (jamais IP directe)
# =============================================================================

# -----------------------------------------------------------------------------
# AMI Ubuntu 22.04 LTS (meme que backend pour coherence)
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# IAM Instance Profile — LabInstanceProfile (existant AWS Academy)
# NE PAS creer de role custom (CreateRole bloque en AWS Academy Sandbox)
# -----------------------------------------------------------------------------
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

# -----------------------------------------------------------------------------
# Instance EC2 Frontend — subnet PUBLIC AZ-A
# Exigence prof : accessible en HTTP depuis internet (port 80)
# nginx reverse-proxie le port 80 vers le conteneur frontend (port 3000)
# -----------------------------------------------------------------------------
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id  # Subnet PUBLIC uniquement
  vpc_security_group_ids = [var.sg_frontend_id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name

  # IP publique automatique (subnet public avec map_public_ip_on_launch = true)
  associate_public_ip_address = true

  # User Data — deploiement automatique du frontend au boot
  user_data = base64encode(templatefile("${path.module}/user_data_frontend.sh.tpl", {
    dockerhub_username                 = var.dockerhub_username
    dockerhub_token                    = var.dockerhub_token
    frontend_image                     = var.frontend_image
    alb_dns_name                       = var.alb_dns_name
    next_public_stripe_publishable_key = var.next_public_stripe_publishable_key
  }))

  # Stockage root : 20 Go gp3
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Metadonnees IMDSv2 (securite recommandee)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-frontend"
    Environment = var.environment
    Role        = "frontend"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group — logs de l'instance frontend
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ec2/${var.app_name}-${var.environment}-frontend"
  retention_in_days = 7

  tags = { Name = "${var.app_name}-${var.environment}-frontend-logs" }
}
