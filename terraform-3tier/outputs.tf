output "public_clb_dns" {
  description = "DNS name of the public-facing CLB (frontend)"
  value       = module.alb.public_clb_dns
}

output "internal_clb_dns" {
  description = "DNS name of the internal CLB (app tier)"
  value       = module.alb.internal_clb_dns
}

output "rds_primary_endpoint" {
  description = "Primary RDS endpoint (write)"
  value       = module.rds.db_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "web_sg_id" {
  description = "Web tier security group ID"
  value       = module.security_groups.web_sg_id
}

output "web_instance_ips" {
  description = "Public IP of web EC2 instance"
  value       = module.ec2.web_public_ips
}

output "app_instance_ips" {
  description = "Private IP of app EC2 instance"
  value       = module.ec2.app_private_ips
}

