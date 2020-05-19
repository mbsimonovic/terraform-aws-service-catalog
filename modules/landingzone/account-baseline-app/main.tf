# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR APP ACCOUNTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# AWS CONFIG
# ----------------------------------------------------------------------------------------------------------------------

module "config" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-config-multi-region?ref=v0.30.0"

  aws_account_id         = var.aws_account_id
  global_recorder_region = var.aws_region

  s3_bucket_name                        = var.config_s3_bucket_name != null ? var.config_s3_bucket_name : "${var.name_prefix}-config"
  should_create_s3_bucket               = var.config_should_create_s3_bucket
  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  opt_in_regions                        = var.config_opt_in_regions

  central_account_id = var.config_central_account_id

  tags = var.config_tags
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_cross_account_roles" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cross-account-iam-roles?ref=v0.30.0"

  aws_account_id = var.aws_account_id

  should_require_mfa     = var.should_require_mfa
  dev_permitted_services = var.dev_permitted_services

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns

  auto_deploy_permissions                   = var.auto_deploy_permissions
  allow_auto_deploy_from_other_account_arns = var.allow_auto_deploy_from_other_account_arns
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-user-password-policy?ref=v0.30.0"

  # Adjust these settings as appropriate for your company
  minimum_password_length        = var.iam_password_policy_minimum_password_length
  require_numbers                = var.iam_password_policy_require_numbers
  require_symbols                = var.iam_password_policy_require_symbols
  require_lowercase_characters   = var.iam_password_policy_require_lowercase_characters
  require_uppercase_characters   = var.iam_password_policy_require_uppercase_characters
  allow_users_to_change_password = true
  hard_expiry                    = true
  max_password_age               = var.iam_password_policy_max_password_age
  password_reuse_prevention      = var.iam_password_policy_password_reuse_prevention

}

# ----------------------------------------------------------------------------------------------------------------------
# GUARDDUTY
# ----------------------------------------------------------------------------------------------------------------------

module "guardduty" {
  source         = "git::git@github.com:gruntwork-io/module-security.git//modules/guardduty-multi-region?ref=v0.30.0"
  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region

  cloudwatch_event_rule_name   = var.guardduty_cloudwatch_event_rule_name
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency
  findings_sns_topic_name      = var.guardduty_findings_sns_topic_name
  opt_in_regions               = var.guardduty_opt_in_regions
  publish_findings_to_sns      = var.guardduty_publish_findings_to_sns
}

# ----------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL
# ----------------------------------------------------------------------------------------------------------------------

module "cloudtrail" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cloudtrail?ref=v0.30.0"

  aws_account_id = var.aws_account_id

  cloudtrail_trail_name = var.name_prefix
  s3_bucket_name        = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : "${var.name_prefix}-cloudtrail"

  num_days_after_which_archive_log_data = var.cloudtrail_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.cloudtrail_num_days_after_which_delete_log_data

  # Note that users with IAM permissions to CloudTrail can still view the last 7 days of data in the AWS Web Console
  kms_key_user_iam_arns            = var.cloudtrail_kms_key_user_iam_arns
  kms_key_administrator_iam_arns   = var.cloudtrail_kms_key_administrator_iam_arns
  allow_cloudtrail_access_with_iam = var.allow_cloudtrail_access_with_iam

  # If you're writing CloudTrail logs to an existing S3 bucket in another AWS account, set this to true
  s3_bucket_already_exists = var.cloudtrail_s3_bucket_already_exists

  # If external AWS accounts need to write CloudTrail logs to the S3 bucket in this AWS account, provide those
  # external AWS account IDs here
  external_aws_account_ids_with_write_access = var.cloudtrail_external_aws_account_ids_with_write_access

  force_destroy = var.cloudtrail_force_destroy
}

# ----------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL KMS CMKS
# ----------------------------------------------------------------------------------------------------------------------

module "customer_master_keys" {
  source         = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key-multi-region?ref=v0.30.0"
  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region

  customer_master_keys = var.kms_customer_master_keys
  global_tags          = var.kms_cmk_global_tags
  opt_in_regions       = var.kms_cmk_opt_in_regions
}

# ----------------------------------------------------------------------------------------------------------------------
# SNS TOPIC
# Optionally create an SNS topic for CloudWatch alarms or any other reason. If sns_topic_name is empty,
# no topic will be created
# ----------------------------------------------------------------------------------------------------------------------

module "sns_topic" {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/sns-topics?ref=v0.30.0"

  create_resources = var.sns_topic_name != null

  name              = var.sns_topic_name
  slack_webhook_url = var.slack_webhook_url
}
