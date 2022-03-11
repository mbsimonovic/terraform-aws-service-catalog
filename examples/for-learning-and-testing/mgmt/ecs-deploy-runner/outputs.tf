output "ecs_cluster_arn" {
  description = "AWS ARN of the ECS Cluster that can be used to run the deploy runner task."
  value       = module.ecs_deploy_runner.ecs_cluster_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group used to store the log output from the Deploy Runner ECS task."
  value       = module.ecs_deploy_runner.cloudwatch_log_group_name
}

output "invoker_function_arn" {
  description = "AWS ARN of the invoker lambda function that can be used to invoke a deployment."
  value       = module.ecs_deploy_runner.invoker_function_arn
}
