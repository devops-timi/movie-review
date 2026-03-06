output "web_public_ips"  { 
  value = aws_instance.web[*].public_ip
}

output "app_private_ips" { 
  value = aws_instance.app[*].private_ip 
}

