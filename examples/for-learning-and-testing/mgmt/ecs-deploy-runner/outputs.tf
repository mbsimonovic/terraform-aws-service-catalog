output "ecs_cluster_arn" {
  description = "AWS ARN of the ECS Cluster that can be used to run the deploy runner task."
  value       = module.ecs_deploy_runner.ecs_cluster_arn
}

output "invoker_function_arn" {
  description = "AWS ARN of the invoker lambda function that can be used to invoke a deployment."
  value       = module.ecs_deploy_runner.invoker_function_arn
}
