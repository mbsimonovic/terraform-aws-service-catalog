output "private_domain_names" {
  value = values(aws_route53_zone.private_zones)[*].name
}

output "private_zones_ids" {
  value = values(aws_route53_zone.private_zones)[*].zone_id 
}

output "private_zones_name_servers" {
  value = values(aws_route53_zone.private_zones)[*].name_servers
}

output "public_domain_names" {
  value = values(aws_route53_zone.public_zones)[*].name
}

output "public_hosted_zones_ids" {
  value = values(aws_route53_zone.public_zones)[*].id
}

output "public_hosted_zones_name_servers" {
  value = values(aws_route53_zone.public_zones)[*].name_servers
}
