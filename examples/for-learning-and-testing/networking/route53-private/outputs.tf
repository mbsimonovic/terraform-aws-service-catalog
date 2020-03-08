output "internal_services_domain_name" {
  value = module.route53-private.internal_services_domain_name
}

output "internal_services_hosted_zone_id" {
  value = module.route53-private.internal_services_hosted_zone_id
}

output "internal_services_name_servers" {
  value = module.route53-private.internal_services_name_servers
}
