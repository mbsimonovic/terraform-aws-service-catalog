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
    domain => zone.created_outside_terraform ? data.aws_route53_zone.selected[domain].zone_id : aws_route53_zone.public_zones[domain].id
  }
}

output "service_discovery_public_namespaces" {
  description = "A map of domains to resource arns and hosted zones of the created Service Discovery Public Namespaces."
  value = {
    for domain, namespace in aws_service_discovery_public_dns_namespace.namespaces :
    domain => {
      id             = namespace.id
      arn            = namespace.arn
      hosted_zone_id = namespace.hosted_zone
    }
  }
}

output "service_discovery_private_namespaces" {
  description = "A map of domains to resource arns and hosted zones of the created Service Discovery Private Namespaces."
  value = {
    for domain, namespace in aws_service_discovery_private_dns_namespace.namespaces :
    domain => {
      id             = namespace.id
      arn            = namespace.arn
      hosted_zone_id = namespace.hosted_zone
    }
  }
}
