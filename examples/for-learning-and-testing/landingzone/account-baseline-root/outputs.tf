# ---------------------------------------------------------------------------------------------------------------------
# CONFIG OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "config_s3_bucket_name" {
  description = "The name of the S3 bucket used by AWS Config to store configuration items."
  value       = module.root_baseline.config_s3_bucket_name
}

output "config_s3_bucket_arn" {
  description = "The ARN of the S3 bucket used by AWS Config to store configuration items."
  value       = module.root_baseline.config_s3_bucket_arn
}

output "config_iam_role_arns" {
  description = "The ARNs of the IAM role used by the config recorder."
  value       = module.root_baseline.config_iam_role_arns
}

output "config_sns_topic_arns" {
  description = "The ARNs of the SNS Topic used by the config notifications."
  value       = module.root_baseline.config_sns_topic_arns
}

output "config_recorder_names" {
  description = "The names of the configuration recorder."
  value       = module.root_baseline.config_recorder_names
}

# ---------------------------------------------------------------------------------------------------------------------
# ORGANIZATIONS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "organization_arn" {
  description = "ARN of the organization."
  value       = module.root_baseline.organization_arn
}

output "organization_id" {
  description = "Identifier of the organization."
  value       = module.root_baseline.organization_id
}

output "master_account_arn" {
  description = "ARN of the master account."
  value       = module.root_baseline.master_account_arn
}

output "master_account_id" {
  description = "Identifier of the master account."
  value       = module.root_baseline.master_account_id
}

output "master_account_email" {
  description = "Email address of the master account."
  value       = module.root_baseline.master_account_email
}

output "child_accounts" {
  description = "A map of all accounts created by this module (NOT including the root account). The keys are the names of the accounts and the values are the attributes for the account as defined in the aws_organizations_account resource."
  value       = module.root_baseline.child_accounts
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "cloudtrail_trail_arn" {
  description = "The ARN of the cloudtrail trail."
  value       = module.root_baseline.cloudtrail_trail_arn
}

output "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 bucket where cloudtrail logs are delivered."
  value       = module.root_baseline.cloudtrail_s3_bucket_name
}

output "cloudtrail_s3_bucket_arn" {
  description = "The ARN of the S3 bucket where cloudtrail logs are delivered."
  value       = module.root_baseline.cloudtrail_s3_bucket_arn
}

output "cloudtrail_kms_key_arn" {
  description = "The ARN of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.root_baseline.cloudtrail_kms_key_arn
}

output "cloudtrail_kms_key_alias_name" {
  description = "The alias of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.root_baseline.cloudtrail_kms_key_alias_name
}

output "cloudtrail_iam_role_name" {
  description = "The name of the IAM role used by the cloudwatch log group."
  value       = module.root_baseline.cloudtrail_iam_role_name
}

output "cloudtrail_iam_role_arn" {
  description = "The ARN of the IAM role used by the cloudwatch log group."
  value       = module.root_baseline.cloudtrail_iam_role_arn
}
