output "service_discovery_public_namespaces" {
  description = "A map of domains to resource arns and hosted zones of the created Service Discovery Public Namespaces."
  value       = module.route53.service_discovery_public_namespaces
}

output "service_discovery_private_namespaces" {
  description = "A map of domains to resource arns and hosted zones of the created Service Discovery Private Namespaces."
  value       = module.route53.service_discovery_private_namespaces
}

output "test_instance_service_discovery_service_name" {
  description = "Service name of the test EC2 instance."
  value       = aws_service_discovery_service.bastion.name
}

output "test_instance_service_discovery_service_id" {
  description = "ID of the test EC2 instance."
  value       = aws_service_discovery_service.bastion.id
}
