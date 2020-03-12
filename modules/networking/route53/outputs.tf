output "private_domain_names" {
  value = [for z in aws_route53_zone.private_zones : z.name]
}

output "private_zones_ids" {
  value = [for z in aws_route53_zone.private_zones : z.zone_id]
}

output "private_zones_name_servers" {
  value = [for z in aws_route53_zone.private_zones : z.name_servers]
}

output "public_domain_names" {
  value = [for z in aws_route53_zone.public_zones : z.name]
}

output "public_hosted_zones_ids" {
  value = [for z in aws_route53_zone.public_zones : z.id]
}

output "public_hosted_zones_name_servers" {
  value = [for z in aws_route53_zone.public_zones : z.name_servers]
}
