output "private_domain_name" {
  description = "The names of the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_domain_names[0]
}

output "private_zone_id" {
  description = "The IDs of the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_zones_ids[0]
}

output "private_zone_name_servers" {
  description = "The name servers associated with the internal-only Route 53 Hosted Zones"
  value       = module.route53.private_zones_name_servers[0]
}

output "mgmt_instance_ip" {
  description = "The IP of the example instance that runs inside the mgmt VPC."
  value       = aws_instance.example["mgmt"].public_ip
}

output "app_instance_ip" {
  description = "The IP of the example instance that runs inside the app VPC."
  value       = aws_instance.example["app"].public_ip
}
