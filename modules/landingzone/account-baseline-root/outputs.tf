# ---------------------------------------------------------------------------------------------------------------------
# CONFIG OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "config_s3_bucket_name" {
  description = "The name of the S3 bucket used by AWS Config to store configuration items."
  value       = var.enable_config ? module.config_bucket.s3_bucket_name : local.config_s3_bucket_name_base
}

output "config_s3_bucket_arn" {
  description = "The ARN of the S3 bucket used by AWS Config to store configuration items."
  value       = module.config_bucket.s3_bucket_arn
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
# ORGANIZATIONS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "organization_arn" {
  description = "ARN of the organization."
  value       = module.organization.organization_arn
}

output "organization_id" {
  description = "Identifier of the organization."
  value       = module.organization.organization_id
}

output "organization_root_id" {
  description = "Identifier of the root of this organization."
  value       = module.organization.organization_root_id
}

output "master_account_arn" {
  description = "ARN of the master account."
  value       = module.organization.master_account_arn
}

output "master_account_id" {
  description = "Identifier of the master account."
  value       = module.organization.master_account_id
}

output "master_account_email" {
  description = "Email address of the master account."
  value       = module.organization.master_account_email
}

output "child_accounts" {
  description = "A map of all accounts created by this module (NOT including the root account). The keys are the names of the accounts and the values are the attributes for the account as defined in the aws_organizations_account resource."
  value       = module.organization.child_accounts
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
  value       = var.enable_cloudtrail ? module.cloudtrail_bucket.s3_bucket_name : local.cloudtrail_s3_bucket_name_with_dependency
}

output "cloudtrail_s3_bucket_arn" {
  description = "The ARN of the S3 bucket where cloudtrail logs are delivered."
  value       = module.cloudtrail_bucket.s3_bucket_arn
}

output "cloudtrail_s3_access_logging_bucket_name" {
  description = "The name of the S3 bucket where access logs for the CloudTrail S3 bucket are delivered."
  value       = module.cloudtrail_bucket.s3_access_logging_bucket_name
}

output "cloudtrail_s3_access_logging_bucket_arn" {
  description = "The ARN of the S3 bucket where access logs for the CloudTrail S3 bucket are delivered."
  value       = module.cloudtrail_bucket.s3_access_logging_bucket_arn
}

output "cloudtrail_kms_key_arn" {
  description = "The ARN of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = var.enable_cloudtrail ? module.cloudtrail_bucket.kms_key_arn : local.cloudtrail_kms_key_arn_with_dependency
}

output "cloudtrail_kms_key_alias_name" {
  description = "The alias of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.cloudtrail_bucket.kms_key_alias_name
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

output "allow_support_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_support_access_from_other_accounts_iam_role_arn
}

output "allow_logs_access_from_other_accounts_iam_role_arn" {
  value = module.iam_cross_account_roles.allow_logs_access_from_other_accounts_iam_role_arn
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

output "allow_support_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_support_access_from_other_accounts_iam_role_id
}

output "allow_logs_access_from_other_accounts_iam_role_id" {
  value = module.iam_cross_account_roles.allow_logs_access_from_other_accounts_iam_role_id
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

output "allow_support_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_support_access_sign_in_url
}

output "allow_logs_access_sign_in_url" {
  value = module.iam_cross_account_roles.allow_logs_access_sign_in_url
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

# ---------------------------------------------------------------------------------------------------------------------
# IAM GROUPS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "billing_iam_group_name" {
  value = module.iam_groups.billing_iam_group_name
}

output "billing_iam_group_arn" {
  value = module.iam_groups.billing_iam_group_arn
}

output "support_iam_group_name" {
  value = module.iam_groups.support_iam_group_name
}

output "support_iam_group_arn" {
  value = module.iam_groups.support_iam_group_arn
}

output "logs_iam_group_name" {
  value = module.iam_groups.logs_iam_group_name
}

output "logs_iam_group_arn" {
  value = module.iam_groups.logs_iam_group_arn
}

output "developers_iam_group_name" {
  value = module.iam_groups.developers_iam_group_name
}

output "developers_iam_group_arn" {
  value = module.iam_groups.developers_iam_group_arn
}

output "full_access_iam_group_name" {
  value = module.iam_groups.full_access_iam_group_name
}

output "full_access_iam_group_arn" {
  value = module.iam_groups.full_access_iam_group_arn
}

output "ssh_grunt_users_group_names" {
  value = module.iam_groups.ssh_grunt_users_group_names
}

output "ssh_grunt_users_group_arns" {
  value = module.iam_groups.ssh_grunt_users_group_arns
}

output "ssh_grunt_sudo_users_group_names" {
  value = module.iam_groups.ssh_grunt_sudo_users_group_names
}

output "ssh_grunt_sudo_users_group_arns" {
  value = module.iam_groups.ssh_grunt_sudo_users_group_arns
}

output "read_only_iam_group_name" {
  value = module.iam_groups.read_only_iam_group_name
}

output "read_only_iam_group_arn" {
  value = module.iam_groups.read_only_iam_group_arn
}

output "houston_cli_users_iam_group_name" {
  value = module.iam_groups.houston_cli_users_iam_group_name
}

output "houston_cli_users_iam_group_arn" {
  value = module.iam_groups.houston_cli_users_iam_group_arn
}

output "use_existing_iam_roles_iam_group_name" {
  value = module.iam_groups.use_existing_iam_roles_iam_group_name
}

output "use_existing_iam_roles_iam_group_arn" {
  value = module.iam_groups.use_existing_iam_roles_iam_group_arn
}

output "iam_self_mgmt_iam_group_name" {
  value = module.iam_groups.iam_self_mgmt_iam_group_name
}

output "iam_self_mgmt_iam_group_arn" {
  value = module.iam_groups.iam_self_mgmt_iam_group_arn
}

output "iam_self_mgmt_iam_policy_arn" {
  value = module.iam_groups.iam_self_mgmt_iam_policy_arn
}

output "iam_admin_iam_group_name" {
  value = module.iam_groups.iam_admin_iam_group_name
}

output "iam_admin_iam_group_arn" {
  value = module.iam_groups.iam_admin_iam_group_arn
}

output "iam_admin_iam_policy_arn" {
  value = module.iam_groups.iam_admin_iam_policy_arn
}

output "require_mfa_policy" {
  value = module.iam_groups.require_mfa_policy
}

output "cross_account_access_group_arns" {
  value = module.iam_groups.cross_account_access_group_arns
}

output "cross_account_access_group_names" {
  value = module.iam_groups.cross_account_access_group_names
}

output "cross_account_access_all_group_arn" {
  value = module.iam_groups.cross_account_access_all_group_arn
}

output "cross_account_access_all_group_name" {
  value = module.iam_groups.cross_account_access_all_group_name
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM USERS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "user_arns" {
  description = "A map of user name to the ARN for that IAM user."
  value       = module.iam_users.user_arns
}

output "user_passwords" {
  description = "A map of user name to that user's AWS Web Console password, encrypted with that user's PGP key (only shows up for users with create_login_profile = true). You can decrypt the password on the CLI: echo <password> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users.user_passwords
}

output "user_access_keys" {
  description = "A map of user name to that user's access keys (a map with keys access_key_id and secret_access_key), with the secret_access_key encrypted with that user's PGP key (only shows up for users with create_access_keys = true). You can decrypt the secret_access_key on the CLI: echo <secret_access_key> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users.user_access_keys
}

# ---------------------------------------------------------------------------------------------------------------------
# EBS DEFAULT ENCRYPTION OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "aws_ebs_encryption_by_default_enabled" {
  description = "A map from region to a boolean indicating whether or not EBS encryption is enabled by default for each region."
  value       = module.ebs_encryption.aws_ebs_encryption_by_default_enabled
}

output "aws_ebs_encryption_default_kms_key" {
  description = "A map from region to the ARN of the KMS key used for default EBS encryption for each region."
  value       = module.ebs_encryption.aws_ebs_encryption_default_kms_key
}
