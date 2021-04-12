output "service_iam_role_name" {
  description = "The name of the service role associated with the ELB of the ECS service"
  value       = module.ecs_service.service_iam_role_name

}

output "service_iam_role_arn" {
  description = "The ARN of the service role associated with the ELB of the ECS service"
  value       = module.ecs_service.service_iam_role_arn
}

output "service_app_autoscaling_target_arn" {
  description = "The ARN of the app autoscaling target"
  value       = module.ecs_service.service_app_autoscaling_target_arn
}

output "service_app_autoscaling_target_resource_id" {
  description = "The resource ID of the autoscaling target"
  value       = module.ecs_service.service_app_autoscaling_target_resource_id

}

output "service_arn" {
  description = "The ARN of the ECS service"
  value       = module.ecs_service.service_arn
}

output "canary_service_arn" {
  description = "The ARN of the canary service. Canary services are optional and can be helpful when you're attempting to verify a release candidate"
  value       = module.ecs_service.canary_service_arn
}

output "ecs_task_iam_role_name" {
  description = "The name of the IAM role granting permissions to the running ECS task itself. Note this role is separate from the execution role which is assumed by the ECS container agent"
  value       = module.ecs_service.ecs_task_iam_role_name
}

output "ecs_task_iam_role_arn" {
  description = "The ARN of the IAM role associated with the ECS task"
  value       = module.ecs_service.ecs_task_iam_role_arn
}

output "ecs_task_execution_iam_role_name" {
  description = "The name of the ECS task execution IAM role. The execution role is used by the ECS container agent to make calls to the ECS API, pull container images from ECR, use the logs driver, etc"
  value       = module.ecs_service.ecs_task_execution_iam_role_name
}

output "ecs_task_execution_iam_role_arn" {
  description = "The ARN of the ECS task's IAM role"
  value       = module.ecs_service.ecs_task_execution_iam_role_arn
}

output "aws_ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition"
  value       = module.ecs_service.aws_ecs_task_definition_arn
}

output "aws_ecs_task_definition_canary_arn" {
  description = "The ARN of the canary ECS task definition"
  value       = module.ecs_service.aws_ecs_task_definition_canary_arn
}

output "target_group_names" {
  description = "The names of the ECS service's load balancer's target groups"
  value       = module.ecs_service.target_group_names
}

output "target_group_arns" {
  description = "The ARNs of the ECS service's load balancer's target groups"
  value       = module.ecs_service.target_group_arns
}

output "capacity_provider_strategy" {
  description = "The capacity provider strategy determines how infrastructure (such as EC2 instances or Fargate) that backs your ECS service is managed. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-capacity-providers.html for more information"
  value       = module.ecs_service.capacity_provider_strategy
}

output "ecs_node_port_mappings" {
  description = "A map representing the instance host and container ports that should be opened"
  value       = var.ecs_node_port_mappings
}

output "route53_domain_name" {
  description = "The domain name of the optional route53 record, which points at the load balancer for the ECS service"
  value       = var.create_route53_entry ? aws_route53_record.service[0].name : null
}

# CloudWatch Dashboard Widgets

output "all_metric_widgets" {
  description = "A list of all the CloudWatch Dashboard metric widgets available in this module."
  value = [
    module.metric_widget_ecs_service_cpu_usage.widget,
    module.metric_widget_ecs_service_memory_usage.widget,
  ]
}

output "metric_widget_ecs_service_cpu_usage" {
  description = "The metric widget for the ECS service's CPU usage "
  value       = module.metric_widget_ecs_service_cpu_usage.widget
}

output "metric_widget_ecs_service_memory_usage" {
  description = "The metric widget for the ECS service's memory usage"
  value       = module.metric_widget_ecs_service_memory_usage.widget
}
