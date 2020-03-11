output "internal_services_domain_name" {
  value = [for s in aws_route53_zone.internal_services : s.name]
}

output "internal_services_hosted_zone_id" {
  value = [for s in aws_route53_zone.internal_services : s.zone_id]
}

output "internal_services_name_servers" {
  value = [for s in aws_route53_zone.internal_services : s.name_servers]
}
