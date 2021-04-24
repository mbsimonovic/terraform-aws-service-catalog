output "function_name" {
  value = module.lambda_function.function_name
}

output "function_arn" {
  value = module.lambda_function.function_arn
}

output "iam_role_id" {
  value = module.lambda_function.iam_role_id
}

output "iam_role_arn" {
  value = module.lambda_function.iam_role_arn
}

output "security_group_id" {
  value = module.lambda_function.security_group_id
}

output "invoke_arn" {
  value = module.lambda_function.invoke_arn
}

output "qualified_arn" {
  value = module.lambda_function.qualified_arn
}

output "version" {
  value = module.lambda_function.version
}

output "event_rule_arn" {
  description = "Cloudwatch Event Rule Arn"
  value       = module.lambda_function.event_rule_arn
}

output "event_rule_schedule" {
  description = "Cloudwatch Event Rule schedule expression"
  value       = module.lambda_function.event_rule_schedule
}

output "alarm_name" {
  description = "Name of the Cloudwatch alarm"
  value       = module.lambda_function.alarm_name
}

output "alarm_arn" {
  description = "ARN of the Cloudwatch alarm"
  value       = module.lambda_function.alarm_arn
}
