output "private_domain_names" {
  description = "The names of the internal-only Route 53 Hosted Zones"
  value       = values(aws_route53_zone.private_zones)[*].name
}

output "private_zones_ids" {
  description = "The IDs of the internal-only Route 53 Hosted Zones"
  value       = values(aws_route53_zone.private_zones)[*].zone_id
}

output "private_zones_name_servers" {
  description = "The name servers associated with the internal-only Route 53 Hosted Zones"
  value       = values(aws_route53_zone.private_zones)[*].name_servers
}

output "public_domain_names" {
  description = "The names of the public Route 53 Hosted Zones"
  value       = values(aws_route53_zone.public_zones)[*].name
}

output "public_hosted_zones_ids" {
  description = "The IDs of the public Route 53 Hosted Zones"
  value       = values(aws_route53_zone.public_zones)[*].id
}

output "public_hosted_zones_name_servers" {
  description = "The name servers associated with the public Route 53 Hosted Zones"
  value       = values(aws_route53_zone.public_zones)[*].name_servers
}

output "public_hosted_zone_map" {
  description = "A map of domains to their zone IDs. IDs are user inputs, when supplied, and otherwise resource IDs"
  value = { for domain, zone in var.public_zones :
    domain => zone.exists ? data.aws_route53_zone.selected[domain].zone_id : aws_route53_zone.public_zones[domain].id
  }
}
