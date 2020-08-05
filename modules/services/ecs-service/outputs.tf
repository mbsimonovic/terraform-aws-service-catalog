output "ecs_task_iam_role_arn" {
  value = module.ecs_service.ecs_task_iam_role_arn
}

output "ecs_node_port_mappings" {
  value = var.ecs_node_port_mappings
}

output "metric_widget_ecs_service_cpu_usage" {
  value = module.metric_widget_ecs_service_cpu_usage.widget
}

output "metric_widget_ecs_service_memory_usage" {
  value = module.metric_widget_ecs_service_memory_usage.widget
}

output "target_group_arns" {
  value = module.ecs_service.target_group_arns
}

output "route53_domain_name" {
  description = "The domain name of the optional route53 record, which points at the load balancer for the ECS service"
  value       = var.create_route53_entry ? aws_route53_record.service[0].name : null
}
