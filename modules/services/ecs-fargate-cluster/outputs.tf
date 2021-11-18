output "arn" {
  description = "ARN of the ECS cluster that was created."
  value       = aws_ecs_cluster.fargate_only.arn
}

output "name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.fargate_only.name
}
