output "vpc_id" {
    value = aws_vpc.this.id 
}

output "web_subnet_ids" {
    value = aws_subnet.web[*].id 
}

output "app_subnet_ids" {
    value = aws_subnet.app[*].id 
}

output "db_subnet_ids" {
    value = aws_subnet.db[*].id 
}