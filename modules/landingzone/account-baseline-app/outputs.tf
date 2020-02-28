# ---------------------------------------------------------------------------------------------------------------------
# CONFIG OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "config_s3_bucket_names" {
  description = "The names of the S3 bucket used by AWS Config to store configuration items."
  value       = module.config.config_s3_bucket_names
}

output "config_iam_role_arns" {
  description = "The ARNs of the IAM role used by the config recorder."
  value       = module.config.config_iam_role_arns
}

output "config_sns_topic_arns" {
  description = "The ARNs of the SNS Topic used by the config notifications."
  value       = module.config.config_sns_topic_arns
}

output "config_recorder_names" {
  description = "The names of the configuration recorder."
  value       = module.config.config_recorder_names
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "cloudtrail_trail_arn" {
  description = "The ARN of the cloudtrail trail."
  value       = module.cloudtrail.trail_arn
}

output "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 bucket where cloudtrail logs are delivered."
  value       = module.cloudtrail.s3_bucket_name
}

output "cloudtrail_s3_access_logging_bucket_name" {
  description = "The name of the S3 bucket where server access logs are delivered."
  value       = module.cloudtrail.s3_access_logging_bucket_name
}

output "cloudtrail_kms_key_arn" {
  description = "The ARN of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.cloudtrail.kms_key_arn
}

output "cloudtrail_kms_key_alias_name" {
  description = "The alias of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.cloudtrail.kms_key_alias_name
}

output "cloudtrail_cloudwatch_group_name" {
  description = "The name of the cloudwatch log group."
  value       = module.cloudtrail.cloudwatch_group_name
}

output "cloudtrail_cloudwatch_group_arn" {
  description = "The ARN of the cloudwatch log group."
  value       = module.cloudtrail.cloudwatch_group_arn
}

output "cloudtrail_iam_role_name" {
  description = "The name of the IAM role used by the cloudwatch log group."
  value       = module.cloudtrail.cloudtrail_iam_role_name
}

output "cloudtrail_iam_role_arn" {
  description = "The ARN of the IAM role used by the cloudwatch log group."
  value       = module.cloudtrail.cloudtrail_iam_role_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# CROSS ACCOUNT IAM ROLES OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "allow_read_only_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_read_only_access_from_other_accounts_iam_role_arn
}

output "allow_billing_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_billing_access_from_other_accounts_iam_role_arn
}

output "allow_ssh_grunt_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_ssh_grunt_access_from_other_accounts_iam_role_arn
}

output "allow_ssh_grunt_houston_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_ssh_grunt_houston_access_from_other_accounts_iam_role_arn
}

output "allow_houston_cli_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_houston_cli_access_from_other_accounts_iam_role_arn
}

output "allow_dev_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_dev_access_from_other_accounts_iam_role_arn
}

output "allow_full_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_full_access_from_other_accounts_iam_role_arn
}

output "allow_iam_admin_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_iam_admin_access_from_other_accounts_iam_role_arn
}

output "allow_auto_deploy_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_auto_deploy_access_from_other_accounts_iam_role_arn
}

output "allow_read_only_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_read_only_access_from_other_accounts_iam_role_id
}

output "allow_billing_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_billing_access_from_other_accounts_iam_role_id
}

output "allow_ssh_grunt_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_ssh_grunt_access_from_other_accounts_iam_role_id
}

output "allow_ssh_grunt_houston_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_ssh_grunt_houston_access_from_other_accounts_iam_role_id
}

output "allow_houston_cli_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_houston_cli_access_from_other_accounts_iam_role_id
}

output "allow_dev_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_dev_access_from_other_accounts_iam_role_id
}

output "allow_full_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_full_access_from_other_accounts_iam_role_id
}

output "allow_iam_admin_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_iam_admin_access_from_other_accounts_iam_role_id
}

output "allow_auto_deploy_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_auto_deploy_access_from_other_accounts_iam_role_id
}

output "allow_read_only_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_read_only_access_sign_in_url
}

output "allow_billing_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_billing_access_sign_in_url
}

output "allow_ssh_grunt_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_read_only_access_from_other_accounts_iam_role_arn
}

output "allow_ssh_grunt_houston_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_ssh_grunt_access_sign_in_url
}

output "allow_dev_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_dev_access_sign_in_url
}

output "allow_full_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_full_access_sign_in_url
}

output "allow_iam_admin_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_iam_admin_access_sign_in_url
}

# ---------------------------------------------------------------------------------------------------------------------
# GUARDDUTY OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "guardduty_detector_ids" {
  description = "The IDs of the GuardDuty detectors."
  value       = module.guardduty.guardduty_detector_ids
}

output "guardduty_cloudwatch_event_rule_arns" {
  description = "The ARNs of the cloudwatch event rules used to publish findings to sns if var.publish_findings_to_sns is set to true."
  value       = module.guardduty.cloudwatch_event_rule_arns
}

output "guardduty_cloudwatch_event_target_arns" {
  description = "The ARNs of the cloudwatch event targets used to publish findings to sns if var.publish_findings_to_sns is set to true."
  value       = module.guardduty.cloudwatch_event_target_arns
}

output "guardduty_findings_sns_topic_arns" {
  description = "The ARNs of the SNS topics where findings are published if var.publish_findings_to_sns is set to true."
  value       = module.guardduty.findings_sns_topic_arns
}

output "guardduty_findings_sns_topic_names" {
  description = "The names of the SNS topic where findings are published if var.publish_findings_to_sns is set to true."
  value       = module.guardduty.findings_sns_topic_names
}
