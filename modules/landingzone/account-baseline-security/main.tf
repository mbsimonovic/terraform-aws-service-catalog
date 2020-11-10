# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR SECURITY ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.58"
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# AWS CONFIG
# ----------------------------------------------------------------------------------------------------------------------

module "config" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-config-multi-region?ref=v0.41.1"

  aws_account_id         = var.aws_account_id
  seed_region            = var.aws_region
  global_recorder_region = var.aws_region

  s3_bucket_name                        = var.config_s3_bucket_name != null ? var.config_s3_bucket_name : "${var.name_prefix}-config"
  should_create_s3_bucket               = var.config_should_create_s3_bucket
  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  opt_in_regions                        = var.config_opt_in_regions

  aggregate_config_data_in_external_account = var.config_aggregate_config_data_in_external_account
  linked_accounts                           = var.config_linked_accounts
  central_account_id                        = var.config_central_account_id

  tags = var.config_tags
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_groups" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-groups?ref=v0.41.1"

  aws_account_id     = var.aws_account_id
  should_require_mfa = var.should_require_mfa

  iam_group_developers_permitted_services = var.iam_group_developers_permitted_services

  iam_groups_for_cross_account_access = var.iam_groups_for_cross_account_access
  cross_account_access_all_group_name = var.cross_account_access_all_group_name

  should_create_iam_group_full_access              = var.should_create_iam_group_full_access
  should_create_iam_group_billing                  = var.should_create_iam_group_billing
  should_create_iam_group_logs                     = var.should_create_iam_group_logs
  should_create_iam_group_developers               = var.should_create_iam_group_developers
  should_create_iam_group_read_only                = var.should_create_iam_group_read_only
  should_create_iam_group_support                  = var.should_create_iam_group_support
  should_create_iam_group_user_self_mgmt           = var.should_create_iam_group_user_self_mgmt
  should_create_iam_group_use_existing_iam_roles   = var.should_create_iam_group_use_existing_iam_roles
  should_create_iam_group_auto_deploy              = var.should_create_iam_group_auto_deploy
  should_create_iam_group_houston_cli_users        = var.should_create_iam_group_houston_cli_users
  should_create_iam_group_cross_account_access_all = var.should_create_iam_group_cross_account_access_all

  iam_group_name_full_access            = var.iam_group_name_full_access
  iam_group_name_billing                = var.iam_group_name_billing
  iam_group_name_logs                   = var.iam_group_name_logs
  iam_group_name_developers             = var.iam_group_name_developers
  iam_group_name_read_only              = var.iam_group_name_read_only
  iam_group_names_ssh_grunt_sudo_users  = var.iam_group_names_ssh_grunt_sudo_users
  iam_group_names_ssh_grunt_users       = var.iam_group_names_ssh_grunt_users
  iam_group_name_use_existing_iam_roles = var.iam_group_name_use_existing_iam_roles
  iam_group_name_auto_deploy            = var.iam_group_name_auto_deploy
  iam_group_name_houston_cli            = var.iam_group_name_houston_cli
  iam_group_name_support                = var.iam_group_name_support
  iam_group_name_iam_user_self_mgmt     = var.iam_group_name_iam_user_self_mgmt
  iam_policy_iam_user_self_mgmt         = var.iam_policy_iam_user_self_mgmt
  iam_group_name_iam_admin              = var.iam_group_name_iam_admin
  auto_deploy_permissions               = var.auto_deploy_permissions

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn
}

module "iam_users" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-users?ref=v0.41.1"

  users                   = var.users
  password_length         = var.iam_password_policy_minimum_password_length
  password_reset_required = var.password_reset_required

  force_destroy = var.force_destroy_users

  # By default we only create the admin and cross account groups in the security account
  # NOTE: If other groups are referenced, it might lead to an error. This could be avoided if the `iam_groups` -module
  #       would provide a list output with all IAM Groups.
  dependencies = [module.iam_groups.iam_admin_iam_group_arn, element(concat(module.iam_groups.cross_account_access_group_arns, [""]), 0)]
}

module "iam_cross_account_roles" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cross-account-iam-roles?ref=v0.41.1"

  aws_account_id = var.aws_account_id

  should_require_mfa     = var.should_require_mfa
  dev_permitted_services = var.dev_permitted_services

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_logs_access_from_other_account_arns      = var.allow_logs_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns

  auto_deploy_permissions                   = var.auto_deploy_permissions
  allow_auto_deploy_from_other_account_arns = var.allow_auto_deploy_from_other_account_arns

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn

  max_session_duration_human_users   = var.max_session_duration_human_users
  max_session_duration_machine_users = var.max_session_duration_machine_users
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-user-password-policy?ref=v0.41.1"

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
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/guardduty-multi-region?ref=v0.41.1"

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
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cloudtrail?ref=v0.41.1"

  is_multi_region_trail = true
  cloudtrail_trail_name = var.name_prefix
  s3_bucket_name        = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : "${var.name_prefix}-cloudtrail"

  num_days_after_which_archive_log_data = var.cloudtrail_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.cloudtrail_num_days_after_which_delete_log_data

  # Set our kms key arn to the one created outside the module. Since we are bringing our own KMS key, we set the kms
  # user vars to empty list.
  kms_key_already_exists         = true
  kms_key_arn                    = local.cloudtrail_kms_key_arn
  kms_key_administrator_iam_arns = []
  kms_key_user_iam_arns          = []

  # Note that users with IAM permissions to CloudTrail can still view the last 7 days of data in the AWS Web Console
  allow_cloudtrail_access_with_iam = var.allow_cloudtrail_access_with_iam

  # If you're writing CloudTrail logs to an existing S3 bucket in another AWS account, set this to true
  s3_bucket_already_exists = var.cloudtrail_s3_bucket_already_exists

  # If external AWS accounts need to write CloudTrail logs to the S3 bucket in this AWS account, provide those
  # external AWS account IDs here
  external_aws_account_ids_with_write_access = var.cloudtrail_external_aws_account_ids_with_write_access

  # Also configure the trail to publish logs to a CloudWatch Logs group within the current account.
  cloudwatch_logs_group_name = var.cloudtrail_cloudwatch_logs_group_name

  force_destroy = var.cloudtrail_force_destroy
}

# If the user did not pass in a custom KMS key ARN create a dedicated one for use with CloudTrail,
# with explicit permissions to allow encrypting the logs for external accounts.
module "cloudtrail_cmk" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key?ref=v0.41.1"

  customer_master_keys = local.maybe_cloudtrail_key
}

locals {
  cloudtrail_cmk_name = "cmk-${var.name_prefix}-cloudtrail"
  dedicated_cloudtrail_key = {
    (local.cloudtrail_cmk_name) = {
      cmk_administrator_iam_arns = var.cloudtrail_kms_key_administrator_iam_arns
      cmk_user_iam_arns = [
        {
          name = var.cloudtrail_kms_key_user_iam_arns
        }
      ]
      cmk_service_principals = [
        {
          name    = "cloudtrail.amazonaws.com"
          actions = ["kms:GenerateDataKey*"]
          conditions = [{
            test     = "StringLike"
            variable = "kms:EncryptionContext:aws:cloudtrail:arn"
            values = concat([
              "arn:aws:cloudtrail:*:${var.aws_account_id}:trail/${var.name_prefix}"
              ],
              [
                for account_id in var.cloudtrail_external_aws_account_ids_with_write_access :
                "arn:aws:cloudtrail:*:${account_id}:trail/*"
              ],
            )
          }]
        },
        {
          name    = "cloudtrail.amazonaws.com"
          actions = ["kms:DescribeKey"]
        },
      ]
    }
  }
  maybe_cloudtrail_key   = var.cloudtrail_kms_key_arn == null ? local.dedicated_cloudtrail_key : {}
  cloudtrail_kms_key_arn = var.cloudtrail_kms_key_arn == null ? module.cloudtrail_cmk.key_arn[local.cloudtrail_cmk_name] : var.cloudtrail_kms_key_arn
}

# ----------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL KMS CMKS
# ----------------------------------------------------------------------------------------------------------------------

module "customer_master_keys" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key-multi-region?ref=v0.41.1"

  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region

  customer_master_keys = var.kms_customer_master_keys
  global_tags          = var.kms_cmk_global_tags
  opt_in_regions       = var.kms_cmk_opt_in_regions
}

module "kms_grants" {
  source            = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-grant-multi-region?ref=v0.41.1"
  aws_account_id    = var.aws_account_id
  seed_region       = var.aws_region
  opt_in_regions    = var.kms_cmk_opt_in_regions
  kms_grant_regions = var.kms_grant_regions
  kms_grants        = var.kms_grants
}
