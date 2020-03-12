output "private_domain_names" {
  value = module.route53.private_domain_names
}

output "private_zones_ids" {
  value = module.route53.private_zones_ids
}

output "private_zones_name_servers" {
  value = module.route53.private_zones_name_servers
}

output "public_domain_names" {
  value = module.route53.public_domain_names
}

output "public_hosted_zones_ids" {
  value = module.route53.public_hosted_zones_ids
}

output "public_hosted_zones_name_servers" {
  value = module.route53.public_hosted_zones_ids
}
