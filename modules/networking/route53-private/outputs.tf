output "internal_services_domain_name" {
  value = aws_route53_zone.internal_services.name
}

output "internal_services_hosted_zone_id" {
  value = aws_route53_zone.internal_services.zone_id
}

output "internal_services_name_servers" {
  value = aws_route53_zone.internal_services.name_servers
}
