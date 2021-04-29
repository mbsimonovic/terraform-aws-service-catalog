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
  # Because we are iterating over a dynamically generated value that can exist,
  # or not, we have to perform a not so beautiful workaround to return a single
  # value, or not. Luckily, for terraform 0.15+ this is natively implemented
  # and will become:
  # value = one([for job in module.scheduled_job : job.event_rule_arn])
  value = lookup({ for job in module.scheduled_job : "one" => job.event_rule_arn }, "one", null)
}

output "event_rule_schedule" {
  description = "Cloudwatch Event Rule schedule expression"
  # Because we are iterating over a dynamically generated value that can exist,
  # or not, we have to perform a not so beautiful workaround to return a single
  # value, or not. Luckily, for terraform 0.15+ this is natively implemented
  # and will become:
  # value = one([for job in module.scheduled_job : job.event_rule_schedule])
  value = lookup({ for job in module.scheduled_job : "one" => job.event_rule_schedule }, "one", null)
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH METRIC ALARM OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
output "alarm_name" {
  description = "Name of the Cloudwatch alarm"
  # Because we are iterating over a dynamically generated value that can exist,
  # or not, we have to perform a not so beautiful workaround to return a single
  # value, or not. Luckily, for terraform 0.15+ this is natively implemented
  # and will become:
  # value = one([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.alarm_name])
  value = lookup({ for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : "one" => alarm.alarm_name }, "one", null)
}

output "alarm_arn" {
  description = "ARN of the Cloudwatch alarm"
  # Because we are iterating over a dynamically generated value that can exist,
  # or not, we have to perform a not so beautiful workaround to return a single
  # value, or not. Luckily, for terraform 0.15+ this is natively implemented
  # and will become:
  # value = one([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.arn])
  value = lookup({ for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : "one" => alarm.arn }, "one", null)
}

output "alarm_actions" {
  description = "The list of actions to execute when this alarm transitions into an ALARM state from any other state"
  # alarm.alarm_actions is a set so, without flatten(), we end up with a list
  # of a set (similar to a list of lists). This way we end up with a single list
  value = flatten([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.alarm_actions])
}

output "ok_actions" {
  description = "The list of actions to execute when this alarm transitions into an OK state from any other state"
  # alarm.ok_actions is a set so, without flatten(), we end up with a list
  # of a set (similar to a list of lists). This way we end up with a single list
  value = flatten([for alarm in aws_cloudwatch_metric_alarm.lambda_failure_alarm : alarm.ok_actions])
}
