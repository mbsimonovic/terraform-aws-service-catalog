output "ecs_cluster_arn" {
  description = "AWS ARN of the ECS Cluster that can be used to run the deploy runner task."
  value       = module.ecs_deploy_runner.ecs_cluster_arn
}

output "ecs_task_arns" {
  description = "Map of AWS ARNs of the ECS Task Definition. There are four entries, one for each container in the standard config (docker-image-builder ; ami-builder ; terraform-planner ; terraform-applier)."
  value       = module.ecs_deploy_runner.ecs_task_arns
}

output "ecs_task_iam_roles" {
  description = "Map of AWS ARNs and names of the IAM role that will be attached to the ECS task to grant it access to AWS resources. Each container will have its own IAM role. There are four entries, one for each container in the standard config (docker-image-builder ; ami-builder ; terraform-planner ; terraform-applier)."
  value       = module.ecs_deploy_runner.ecs_task_iam_roles
}

output "default_ecs_task_arn" {
  description = "AWS ARN of the default ECS Task Definition. Can be used to trigger the ECS Task directly."
  value       = module.ecs_deploy_runner.default_ecs_task_arn
}

output "ecs_task_families" {
  description = "Map of the families of the ECS Task Definition that is currently live. There are four entries, one for each container in the standard config (docker-image-builder ; ami-builder ; terraform-planner ; terraform-applier)."
  value       = module.ecs_deploy_runner.ecs_task_families
}

output "ecs_task_revisions" {
  description = "Map of the current revision of the ECS Task Definition that is currently live. There are four entries, one for each container in the standard config (docker-image-builder ; ami-builder ; terraform-planner ; terraform-applier)."
  value       = module.ecs_deploy_runner.ecs_task_revisions
}

output "invoker_function_arn" {
  description = "AWS ARN of the invoker lambda function that can be used to invoke a deployment."
  value       = module.ecs_deploy_runner.invoker_function_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group used to store the log output from the Deploy Runner ECS task."
  value       = module.ecs_deploy_runner.cloudwatch_log_group_name
}

output "security_group_allow_all_outbound_id" {
  description = "Security Group ID of the ECS task"
  value       = module.ecs_deploy_runner.security_group_allow_all_outbound_id
}

output "invoke_policy_arn" {
  description = "The ARN of the IAM policy that allows access to the invoke the deploy runner."
  value       = module.invoke_policy.arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS Task execution role ARN"
  value       = module.ecs_deploy_runner.ecs_task_execution_role_arn
}
