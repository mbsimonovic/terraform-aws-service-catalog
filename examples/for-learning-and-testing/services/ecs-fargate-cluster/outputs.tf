output "ecs_cluster_arn" {
  description = "The ARN of the created ECS cluster"
  value       = module.ecs_cluster.arn
}
