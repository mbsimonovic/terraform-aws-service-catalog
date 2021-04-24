# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA MODULE OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------------------------------------------------
# SCHEDULED LAMBDA JOB MODULE OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "event_rule_arn" {
  description = "Cloudwatch Event Rule Arn"
  value       = [for job in module.scheduled_job : job.event_rule_arn]
  # For Terraform 0.15+
  # This will change the output type from list to string but it will, then, be closer to reality
  # value       = one([for job in module.scheduled_job : job.event_rule_arn])
}

output "event_rule_schedule" {
  description = "Cloudwatch Event Rule schedule expression"
  value       = [for job in module.scheduled_job : job.event_rule_schedule]
  # For Terraform 0.15+
  # This will change the output type from list to string but it will, then, be closer to reality
  # value       = one([for job in module.scheduled_job : job.event_rule_schedule])
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH METRIC ALARM OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
output "alarm_name" {
  description = "Name of the Cloudwatch alarm"
  value       = [for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.alarm_name]
  # For Terraform 0.15+
  # This will change the output type from list to string but it will, then, be closer to reality
  # value       = one([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.alarm_name])
}

output "alarm_arn" {
  description = "ARN of the Cloudwatch alarm"
  value       = [for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.arn]
  # For Terraform 0.15+
  # This will change the output type from list to string but it will, then, be closer to reality
  # value       = one([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.arn])
}
