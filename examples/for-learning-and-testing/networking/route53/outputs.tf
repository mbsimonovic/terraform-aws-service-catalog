output "private_domain_names" {
  description = "The names of the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_domain_names
}

output "private_zones_ids" {
  description = "The IDs of the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_zones_ids
}

output "private_zones_name_servers" {
  description = "The name servers associated with the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_zones_name_servers
}

output "public_domain_names" {
  description = "The names of the public Route 53 Hosted Zones"
  value       = module.route53.public_domain_names
}

output "public_hosted_zones_ids" {
  description = "The IDs of the public Route 53 Hosted Zones"
  value       = module.route53.public_hosted_zones_ids
}

output "public_hosted_zones_name_servers" {
  description = "The name servers associated with the public Route 53 Hosted Zones"
  value       = module.route53.public_zones_name_servers
}
