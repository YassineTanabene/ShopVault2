output "public_ip" {
  description = "IP publique de l'instance EC2 Frontend (accessible depuis internet sur port 80)"
  value       = aws_instance.frontend.public_ip
}

output "public_dns" {
  description = "DNS public de l'instance EC2 Frontend"
  value       = aws_instance.frontend.public_dns
}

output "instance_id" {
  description = "ID de l'instance EC2 Frontend"
  value       = aws_instance.frontend.id
}
