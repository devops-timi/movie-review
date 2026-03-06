output "public_clb_dns" {
  value = aws_elb.public.dns_name
}

output "internal_clb_dns" {
  value = aws_elb.internal.dns_name
}

output "public_clb_name" {
  value = aws_elb.public.name
}

output "internal_clb_name" {
  value = aws_elb.internal.name
}
