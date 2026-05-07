# =============================================================================
# VPC Outputs — exposés aux autres modules Terraform
# =============================================================================

output "vpc_id" {
  description = "ID du VPC principal"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs des sous-réseaux publics (AZ-A + AZ-B) — ALB, NAT GW, Frontend EC2"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs des sous-réseaux privés (AZ-A + AZ-B) — Backend ASG, RDS"
  value       = aws_subnet.private[*].id
}

# -----------------------------------------------------------------------------
# Security Group IDs — un SG dédié par composant (exigence prof)
# -----------------------------------------------------------------------------

output "sg_alb_id" {
  description = "SG Application Load Balancer — inbound 80 depuis 0.0.0.0/0"
  value       = aws_security_group.alb.id
}

output "sg_backend_id" {
  description = "SG EC2 Backend ASG — inbound 4000 depuis SG ALB uniquement"
  value       = aws_security_group.backend.id
}

output "sg_frontend_id" {
  description = "SG EC2 Frontend — inbound 80 (internet) + 22 (debug)"
  value       = aws_security_group.frontend.id
}

output "sg_rds_id" {
  description = "SG RDS PostgreSQL — inbound 5432 depuis SG Backend uniquement"
  value       = aws_security_group.rds.id
}
