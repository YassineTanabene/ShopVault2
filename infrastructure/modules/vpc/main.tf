# =============================================================================
# VPC — ShopVault Network Infrastructure
# Conforme aux exigences académiques (ING 2 Cloud Computing)
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Principal
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.app_name}-${var.environment}-vpc" }
}

# -----------------------------------------------------------------------------
# Internet Gateway — trafic entrant depuis internet
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.app_name}-${var.environment}-igw" }
}

# -----------------------------------------------------------------------------
# Sous-réseaux publics (AZ-A + AZ-B)
# Accueillent : ALB, NAT Gateway, Instance EC2 Frontend
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true
  tags = { Name = "${var.app_name}-${var.environment}-public-${count.index == 0 ? "a" : "b"}" }
}

# -----------------------------------------------------------------------------
# Sous-réseaux privés (AZ-A + AZ-B)
# Accueillent : Instances EC2 Backend (ASG), RDS PostgreSQL
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  tags = { Name = "${var.app_name}-${var.environment}-private-${count.index == 0 ? "a" : "b"}" }
}

# -----------------------------------------------------------------------------
# Elastic IP pour NAT Gateway
# 1 EIP en dev, 1 par AZ en prod
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.environment == "prod" ? 2 : 1
  vpc   = true
  tags  = { Name = "${var.app_name}-${var.environment}-nat-eip-${count.index}" }
}

# -----------------------------------------------------------------------------
# NAT Gateway — dans le subnet public AZ-A
# Permet aux instances privées (backend ASG) d'accéder à internet (docker pull)
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count         = var.environment == "prod" ? 2 : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = { Name = "${var.app_name}-${var.environment}-nat-${count.index}" }
  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Table de routage publique — route 0.0.0.0/0 vers Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.app_name}-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Table de routage privée — route 0.0.0.0/0 vers NAT Gateway
# Les instances backend (ASG) passent par NAT pour docker pull
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = var.environment == "prod" ? 2 : 1
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = { Name = "${var.app_name}-${var.environment}-private-rt-${count.index}" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.environment == "prod" ? count.index : 0].id
}

# =============================================================================
# SECURITY GROUPS — Exigences académiques strictes
# Le correcteur vérifiera CHAQUE règle pendant la démonstration
# =============================================================================

# -----------------------------------------------------------------------------
# SG ALB — Application Load Balancer
# Règle : HTTP port 80 depuis internet uniquement
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-${var.environment}-sg-alb"
  description = "ALB: HTTP depuis internet uniquement"
  vpc_id      = aws_vpc.main.id

  # Inbound : HTTP depuis internet
  ingress {
    description = "HTTP depuis internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound : tout autorisé (vers instances backend)
  egress {
    description = "Tout le trafic sortant autorisé"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-${var.environment}-sg-alb" }
}

# -----------------------------------------------------------------------------
# SG EC2 Backend (ASG)
# Exigence prof : port 4000 UNIQUEMENT depuis SG ALB
# PAS d'accès depuis internet. PAS de règle 0.0.0.0/0 en inbound.
# -----------------------------------------------------------------------------
resource "aws_security_group" "backend" {
  name        = "${var.app_name}-${var.environment}-sg-backend"
  description = "Backend EC2 ASG: port 4000 depuis ALB uniquement"
  vpc_id      = aws_vpc.main.id

  # Inbound : port applicatif backend depuis SG ALB UNIQUEMENT
  ingress {
    description     = "Backend API depuis ALB uniquement"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound : tout autorisé (pour docker pull depuis NAT GW, accès RDS)
  egress {
    description = "Tout le trafic sortant autorisé"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-${var.environment}-sg-backend" }
}

# -----------------------------------------------------------------------------
# SG EC2 Frontend
# Exigence prof : HTTP 80 depuis internet + SSH 22
# ⚠️ SSH sur 0.0.0.0/0 uniquement pour debug — remplacer par votre IP fixe en prod
# Ex: cidr_blocks = ["XX.XX.XX.XX/32"]
# -----------------------------------------------------------------------------
resource "aws_security_group" "frontend" {
  name        = "${var.app_name}-${var.environment}-sg-frontend"
  description = "Frontend EC2: HTTP 80 + SSH 22 (debug)"
  vpc_id      = aws_vpc.main.id

  # Inbound : HTTP depuis internet (accès utilisateurs)
  ingress {
    description = "HTTP depuis internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound : SSH pour debug/déploiement
  # ⚠️ TODO PRODUCTION : remplacer 0.0.0.0/0 par votre IP fixe — ex: ["XX.XX.XX.XX/32"]
  ingress {
    description = "SSH debug - TODO: restreindre à votre IP fixe en production"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound : tout autorisé (pour docker pull, communication avec ALB backend)
  egress {
    description = "Tout le trafic sortant autorisé"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-${var.environment}-sg-frontend" }
}

# -----------------------------------------------------------------------------
# SG RDS PostgreSQL
# Exigence prof : port 5432 UNIQUEMENT depuis SG Backend
# Aucune règle depuis internet. Aucune règle depuis 0.0.0.0/0 sur 5432.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-${var.environment}-sg-rds"
  description = "RDS PostgreSQL: port 5432 depuis backend EC2 uniquement"
  vpc_id      = aws_vpc.main.id

  # Inbound : PostgreSQL depuis SG Backend UNIQUEMENT
  ingress {
    description     = "PostgreSQL depuis backend EC2 ASG uniquement"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # Outbound : tout autorisé
  egress {
    description = "Tout le trafic sortant autorisé"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-${var.environment}-sg-rds" }
}
