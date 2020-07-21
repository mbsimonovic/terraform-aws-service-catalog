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
