# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR ROOT ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"
}

# ----------------------------------------------------------------------------------------------------------------------
# ORGANIZATIONS MODULE AND CHILD ACCOUNTS
# ----------------------------------------------------------------------------------------------------------------------

module "organization" {
  source = "../aws-organizations"

  child_accounts                              = var.child_accounts
  create_organization                         = var.create_organization
  default_iam_user_access_to_billing          = var.organizations_default_iam_user_access_to_billing
  default_role_name                           = var.organizations_default_role_name
  organizations_aws_service_access_principals = var.organizations_aws_service_access_principals
  organizations_enabled_policy_types          = var.organizations_enabled_policy_types
  organizations_feature_set                   = var.organizations_feature_set

  default_tags = var.organizations_default_tags
}


# ----------------------------------------------------------------------------------------------------------------------
# AWS CONFIG AND ORGANIZATION LEVEL CONFIG RULES
# ----------------------------------------------------------------------------------------------------------------------

module "config" {
  source = "../aws-config-multi-region"

  aws_account_id         = var.aws_account_id
  global_recorder_region = var.aws_region
  name_prefix            = var.name_prefix

  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  opt_in_regions                        = var.config_opt_in_regions

  tags = var.config_tags
}

module "organizations_config_rules" {
  source = "../aws-organizations-config-rules"

  // Make sure AWS Config has been applied first
  // Because `aws-config-multi-region` doesn't have a string or list of strings output, we'll construct one dynamically
  dependencies = [
    for k, v in module.config.config_sns_topic_arns :
    v
  ]

  additional_rules                         = var.additional_config_rules
  enable_encrypted_volumes                 = var.enable_encrypted_volumes
  enable_iam_password_policy               = var.enable_iam_password_policy
  enable_insecure_sg_rules                 = var.enable_insecure_sg_rules
  enable_rds_storage_encrypted             = var.enable_rds_storage_encrypted
  enable_root_account_mfa                  = var.enable_root_account_mfa
  enable_s3_bucket_public_read_prohibited  = var.enable_s3_bucket_public_read_prohibited
  enable_s3_bucket_public_write_prohibited = var.enable_s3_bucket_public_write_prohibited

  excluded_accounts                                = var.configrules_excluded_accounts
  iam_password_policy_max_password_age             = var.iam_password_policy_max_password_age
  iam_password_policy_minimum_password_length      = var.iam_password_policy_minimum_password_length
  iam_password_policy_password_reuse_prevention    = var.iam_password_policy_password_reuse_prevention
  iam_password_policy_require_lowercase_characters = var.iam_password_policy_require_lowercase_characters
  iam_password_policy_require_numbers              = var.iam_password_policy_require_numbers
  iam_password_policy_require_symbols              = var.iam_password_policy_require_symbols
  iam_password_policy_require_uppercase_characters = var.iam_password_policy_require_uppercase_characters
  insecure_sg_rules_authorized_udp_ports           = var.insecure_sg_rules_authorized_udp_ports
  insecure_sg_rules_authorized_tcp_ports           = var.insecure_sg_rules_authorized_tcp_ports
  maximum_execution_frequency                      = var.configrules_maximum_execution_frequency
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_groups" {
  source = "../iam-groups"

  aws_account_id     = var.aws_account_id
  should_require_mfa = var.should_require_mfa

  iam_group_developers_permitted_services = var.iam_group_developers_permitted_services

  iam_groups_for_cross_account_access = var.iam_groups_for_cross_account_access
  cross_account_access_all_group_name = var.cross_account_access_all_group_name

  should_create_iam_group_full_access            = var.should_create_iam_group_full_access
  should_create_iam_group_billing                = var.should_create_iam_group_billing
  should_create_iam_group_developers             = var.should_create_iam_group_developers
  should_create_iam_group_read_only              = var.should_create_iam_group_read_only
  should_create_iam_group_user_self_mgmt         = var.should_create_iam_group_user_self_mgmt
  should_create_iam_group_use_existing_iam_roles = var.should_create_iam_group_use_existing_iam_roles
  should_create_iam_group_auto_deploy            = var.should_create_iam_group_auto_deploy
  should_create_iam_group_houston_cli_users      = var.should_create_iam_group_houston_cli_users

  auto_deploy_permissions = var.auto_deploy_permissions
}

module "iam_users" {
  source = "../iam-users"

  users                   = var.users
  password_length         = var.iam_password_policy_minimum_password_length
  password_reset_required = var.password_reset_required

  force_destroy = var.force_destroy_users
}

module "iam_cross_account_roles" {
  source = "../cross-account-iam-roles"

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
  source = "../iam-user-password-policy"

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
  source         = "../guardduty-multi-region"
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
  source = "../cloudtrail"

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
