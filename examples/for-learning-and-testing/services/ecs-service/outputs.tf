output "route53_domain_name" {
  description = "The domain name for the route 53 record that is pointed at the ECS service"
  value       = module.ecs_service.route53_domain_name
}
