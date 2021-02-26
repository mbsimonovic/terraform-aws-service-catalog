output "arn" {
  description = "ARN of the ECS cluster that was created."
  value       = aws_ecs_cluster.fargate_only.arn
}
