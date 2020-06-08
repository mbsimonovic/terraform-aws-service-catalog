output "ecs_cluster_arn" {
  description = "The ID of the ECS cluster"
  value       = module.ecs_cluster.aws_ecs_cluster.ecs.id

  # Explicitly ties the aws_ecs_cluster to the aws_autoscaling_group, so that the resources are created together
  depends_on = [module.ecs_cluster.aws_autoscaling_group.ecs]
}

output "ecs_cluster_launch_configuration_id" {
  description = "The ID of the launch configuration used by the ECS cluster's auto scaling group (ASG)"
  value       = module.ecs_cluster.aws_launch_configuration.ecs.id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs_cluster.aws_ecs_cluster.ecs.name

  # Explicitly ties the aws_ecs_cluster to the aws_autoscaling_group, so that the resources are created together
  depends_on = [module.ecs_cluster.aws_autoscaling_group.ecs]
}

output "ecs_cluster_asg_name" {
  description = "The name of the ECS cluster's autoscaling group (ASG)"
  value       = module.ecs_cluster.aws_autoscaling_group.ecs.name
}

output "ecs_instance_security_group_id" {
  description = "The ID of the security group applied to ECS instances"
  value       = module.ecs_cluster.aws_security_group.ecs.id
}

output "ecs_instance_iam_role_id" {
  description = "The ID of the IAM role applied to ECS instances"
  value       = module.ecs_cluster.aws_iam_role.ecs.id
}

output "ecs_instance_iam_role_arn" {
  description = "The ARN of the IAM role applied to ECS instances"
  value       = module.ecs_cluster.aws_iam_role.ecs.arn
}

output "ecs_instance_iam_role_name" {
  description = "The name of the IAM role applied to ECS instances"
  # Use a RegEx (https://www.terraform.io/docs/configuration/interpolation.html#replace_string_search_replace_) that
  # takes a value like "arn:aws:iam::123456789012:role/S3Access" and looks for the string after the last "/".
  value = replace(module.ecs_cluster.aws_iam_role.ecs.arn, "/.*/+(.*)/", "$1")
}

output "ecs_cluster_vpc_id" {
  description = "The ID of the VPC into which the ECS cluster is launched"
  value       = var.vpc_id
}

output "ecs_cluster_vpc_subnet_ids" {
  description = "The VPC subnet IDs into which the ECS cluster can launch resources into"
  value       = var.vpc_subnet_ids
}
