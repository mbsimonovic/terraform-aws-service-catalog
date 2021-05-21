output "ecs_cluster_arn" {
  description = "The ID of the ECS cluster"
  value       = module.ecs_cluster.ecs_cluster_arn
}

output "ecs_cluster_launch_configuration_id" {
  description = "The ID of the launch configuration used by the ECS cluster's auto scaling group (ASG)"
  value       = module.ecs_cluster.ecs_cluster_launch_configuration_id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs_cluster.ecs_cluster_name
}

output "ecs_cluster_asg_name" {
  description = "The name of the ECS cluster's autoscaling group (ASG)"
  value       = module.ecs_cluster.ecs_cluster_asg_name
}

output "ecs_cluster_asg_names" {
  description = "For configurations with multiple ASGs, this contains a list of ASG names."
  value       = module.ecs_cluster.ecs_cluster_asg_name
}

output "ecs_cluster_capacity_provider_names" {
  description = "For configurations with multiple capacity providers, this contains a list of all capacity provider names."
  value       = module.ecs_cluster.ecs_cluster_capacity_provider_names
}

output "ecs_instance_security_group_id" {
  description = "The ID of the security group applied to ECS instances"
  value       = module.ecs_cluster.ecs_instance_security_group_id
}

output "ecs_instance_iam_role_id" {
  description = "The ID of the IAM role applied to ECS instances"
  value       = module.ecs_cluster.ecs_instance_iam_role_id
}

output "ecs_instance_iam_role_arn" {
  description = "The ARN of the IAM role applied to ECS instances"
  value       = module.ecs_cluster.ecs_instance_iam_role_arn
}

output "ecs_instance_iam_role_name" {
  description = "The name of the IAM role applied to ECS instances"
  value       = module.ecs_cluster.ecs_instance_iam_role_name
}

output "ecs_cluster_vpc_id" {
  description = "The ID of the VPC into which the ECS cluster is launched"
  value       = var.vpc_id
}

output "ecs_cluster_vpc_subnet_ids" {
  description = "The VPC subnet IDs into which the ECS cluster can launch resources into"
  value       = var.vpc_subnet_ids
}

# CloudWatch Dashboard Widgets

output "all_metric_widgets" {
  description = "A list of all the CloudWatch Dashboard metric widgets available in this module."
  value = [
    module.metric_widget_ecs_cluster_cpu_usage.widget,
    module.metric_widget_ecs_cluster_memory_usage.widget,
  ]
}

output "metric_widget_ecs_cluster_cpu_usage" {
  description = "The CloudWatch Dashboard metric widget for the ECS cluster workers' CPU utilization metric."
  value       = module.metric_widget_ecs_cluster_cpu_usage.widget
}

output "metric_widget_ecs_cluster_memory_usage" {
  description = "The CloudWatch Dashboard metric widget for the ECS cluster workers' Memory utilization metric."
  value       = module.metric_widget_ecs_cluster_memory_usage.widget
}
