# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA MODULE OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
output "function_name" {
  description = "Unique name for Lambda Function"
  value       = module.lambda_function.function_name
}

output "function_arn" {
  description = "Amazon Resource Name (ARN) identifying the Lambda Function"
  value       = module.lambda_function.function_arn
}

output "iam_role_id" {
  description = "Name of the AWS IAM Role created for the Lambda Function"
  value       = module.lambda_function.iam_role_id
}

output "iam_role_arn" {
  description = "Amazon Resource Name (ARN) of the AWS IAM Role created for the Lambda Function"
  value       = module.lambda_function.iam_role_arn
}

output "security_group_id" {
  description = "Security Group ID of the Security Group created for the Lambda Function"
  value       = module.lambda_function.security_group_id
}

output "invoke_arn" {
  description = "Amazon Resource Name (ARN) to be used for invoking the Lambda Function"
  value       = module.lambda_function.invoke_arn
}

output "qualified_arn" {
  description = "Amazon Resource Name (ARN) identifying your Lambda Function version"
  value       = module.lambda_function.qualified_arn
}

output "version" {
  description = "Latest published version of your Lambda Function"
  value       = module.lambda_function.version
}

# ---------------------------------------------------------------------------------------------------------------------
# SCHEDULED LAMBDA JOB MODULE OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "event_rule_arn" {
  description = "Cloudwatch Event Rule Arn"
  value       = lookup({ for job in module.scheduled_job : "one" => job.event_rule_arn }, "one", null)
}

output "event_rule_schedule" {
  description = "Cloudwatch Event Rule schedule expression"
  value       = lookup({ for job in module.scheduled_job : "one" => job.event_rule_schedule }, "one", null)
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH METRIC ALARM OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
output "alarm_name" {
  description = "Name of the Cloudwatch alarm"
  value       = module.lambda_alarm.alarm_name
}

output "alarm_arn" {
  description = "ARN of the Cloudwatch alarm"
  value       = module.lambda_alarm.alarm_arn
}

output "alarm_actions" {
  description = "The list of actions to execute when this alarm transitions into an ALARM state from any other state"
  value       = module.lambda_alarm.alarm_actions
}

output "ok_actions" {
  description = "The list of actions to execute when this alarm transitions into an OK state from any other state"
  value       = module.lambda_alarm.ok_actions
}

output "insufficient_data_actions" {
  description = "The list of actions to execute when this alarm transitions into an INSUFFICIENT_DATA state from any other state"
  value       = module.lambda_alarm.insufficient_data_actions
}
