# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR APP ACCOUNTS
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/aws-config-multi-region?ref=v0.46.4"

  create_resources       = var.enable_config
  aws_account_id         = var.aws_account_id
  seed_region            = var.aws_region
  global_recorder_region = var.aws_region

  s3_bucket_name                        = var.config_s3_bucket_name != null ? var.config_s3_bucket_name : "${var.name_prefix}-config"
  should_create_s3_bucket               = var.config_should_create_s3_bucket
  sns_topic_name                        = var.config_sns_topic_name
  should_create_sns_topic               = var.config_should_create_sns_topic
  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  opt_in_regions                        = var.config_opt_in_regions

  linked_accounts                           = var.config_linked_accounts
  aggregate_config_data_in_external_account = var.config_aggregate_config_data_in_external_account
  central_account_id                        = var.config_central_account_id

  tags = var.config_tags

  #### Parameters for AWS Config Rules ####
  # If config_create_account_rules is true, we create account-level Config rules directly in this account.
  # If config_create_account_rules is false, we can only create org-level rules in the root account, so in this account,
  # we create nothing.
  enable_config_rules = var.config_create_account_rules

  additional_config_rules                       = var.additional_config_rules
  enable_iam_password_policy_rule               = var.enable_iam_password_policy
  enable_encrypted_volumes_rule                 = var.enable_encrypted_volumes
  enable_insecure_sg_rules                      = var.enable_insecure_sg_rules
  enable_rds_storage_encrypted_rule             = var.enable_rds_storage_encrypted
  enable_root_account_mfa_rule                  = var.enable_root_account_mfa
  enable_s3_bucket_public_read_prohibited_rule  = var.enable_s3_bucket_public_read_prohibited
  enable_s3_bucket_public_write_prohibited_rule = var.enable_s3_bucket_public_write_prohibited

  iam_password_policy_rule_max_password_age             = var.iam_password_policy_max_password_age
  iam_password_policy_rule_minimum_password_length      = var.iam_password_policy_minimum_password_length
  iam_password_policy_rule_password_reuse_prevention    = var.iam_password_policy_password_reuse_prevention
  iam_password_policy_rule_require_lowercase_characters = var.iam_password_policy_require_lowercase_characters
  iam_password_policy_rule_require_numbers              = var.iam_password_policy_require_numbers
  iam_password_policy_rule_require_symbols              = var.iam_password_policy_require_symbols
  iam_password_policy_rule_require_uppercase_characters = var.iam_password_policy_require_uppercase_characters
  insecure_sg_rules_authorized_udp_ports                = var.insecure_sg_rules_authorized_udp_ports
  insecure_sg_rules_authorized_tcp_ports                = var.insecure_sg_rules_authorized_tcp_ports
  config_rule_maximum_execution_frequency               = var.configrules_maximum_execution_frequency
  encrypted_volumes_kms_id                              = var.encrypted_volumes_kms_id
  rds_storage_encrypted_kms_id                          = var.rds_storage_encrypted_kms_id

  # We used to do org-level rules, but those have a dependency / ordering problem: if you enable org-level rules, they
  # immediately apply to ALL child accounts... But if a child account doesn't have a Config Recorder, it fails. So when
  # adding new child accounts, the deployment always fails, because of course brand new accounts don't have Config
  # Recorders. So by switching to account-level rules, we now have to apply the same rules in each and every account,
  # but we can ensure that the rules are only enforced after the Config Recorder is in place.
  create_account_rules = true
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_cross_account_roles" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cross-account-iam-roles?ref=v0.46.4"

  create_resources = var.enable_iam_cross_account_roles

  aws_account_id = var.aws_account_id
  tags           = var.iam_role_tags

  should_require_mfa     = var.should_require_mfa
  dev_permitted_services = var.dev_permitted_services

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_support_access_from_other_account_arns   = var.allow_support_access_from_other_account_arns
  allow_logs_access_from_other_account_arns      = var.allow_logs_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns

  auto_deploy_permissions                   = var.auto_deploy_permissions
  allow_auto_deploy_from_other_account_arns = var.allow_auto_deploy_from_other_account_arns
  cloudtrail_kms_key_arn                    = module.cloudtrail.kms_key_arn

  max_session_duration_human_users   = var.max_session_duration_human_users
  max_session_duration_machine_users = var.max_session_duration_machine_users
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-user-password-policy?ref=iam-password-policy-create-resources-fix"

  create_resources = var.enable_iam_user_password_policy

  # Adjust these settings as appropriate for your company
  minimum_password_length        = var.iam_password_policy_minimum_password_length
  require_numbers                = var.iam_password_policy_require_numbers
  require_symbols                = var.iam_password_policy_require_symbols
  require_lowercase_characters   = var.iam_password_policy_require_lowercase_characters
  require_uppercase_characters   = var.iam_password_policy_require_uppercase_characters
  allow_users_to_change_password = var.iam_password_policy_allow_users_to_change_password
  hard_expiry                    = var.iam_password_policy_hard_expiry
  max_password_age               = var.iam_password_policy_max_password_age
  password_reuse_prevention      = var.iam_password_policy_password_reuse_prevention
}

# ----------------------------------------------------------------------------------------------------------------------
# GUARDDUTY
# ----------------------------------------------------------------------------------------------------------------------

module "guardduty" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/guardduty-multi-region?ref=v0.46.4"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cloudtrail?ref=v0.46.4"

  create_resources      = var.enable_cloudtrail
  is_multi_region_trail = true
  cloudtrail_trail_name = var.name_prefix
  s3_bucket_name        = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : "${var.name_prefix}-cloudtrail"
  tags                  = var.cloudtrail_tags

  num_days_after_which_archive_log_data = var.cloudtrail_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.cloudtrail_num_days_after_which_delete_log_data

  kms_key_already_exists                          = var.cloudtrail_kms_key_arn != null
  kms_key_arn                                     = var.cloudtrail_kms_key_arn
  kms_key_administrator_iam_arns                  = var.cloudtrail_kms_key_administrator_iam_arns
  kms_key_user_iam_arns                           = var.cloudtrail_kms_key_user_iam_arns
  kms_key_arn_is_alias                            = var.cloudtrail_kms_key_arn_is_alias
  allow_kms_describe_key_to_external_aws_accounts = var.cloudtrail_allow_kms_describe_key_to_external_aws_accounts
  allow_cloudtrail_access_with_iam                = var.allow_cloudtrail_access_with_iam

  # If you're writing CloudTrail logs to an existing S3 bucket in another AWS account, set this to true
  s3_bucket_already_exists = var.cloudtrail_s3_bucket_already_exists

  # If external AWS accounts need to write CloudTrail logs to the S3 bucket in this AWS account, provide those
  # external AWS account IDs here
  external_aws_account_ids_with_write_access = var.cloudtrail_external_aws_account_ids_with_write_access

  # Also configure the trail to publish logs to a CloudWatch Logs group within the current account.
  cloudwatch_logs_group_name = var.cloudtrail_cloudwatch_logs_group_name

  force_destroy = var.cloudtrail_force_destroy
}

# ----------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL KMS CMKS
# ----------------------------------------------------------------------------------------------------------------------

module "customer_master_keys" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-master-key-multi-region?ref=v0.46.4"

  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region

  customer_master_keys = var.kms_customer_master_keys
  global_tags          = var.kms_cmk_global_tags
  opt_in_regions       = var.kms_cmk_opt_in_regions
}

module "kms_grants" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-grant-multi-region?ref=v0.46.4"

  aws_account_id    = var.aws_account_id
  seed_region       = var.aws_region
  opt_in_regions    = var.kms_cmk_opt_in_regions
  kms_grant_regions = var.kms_grant_regions
  kms_grants        = var.kms_grants

  # In order to support creating grants for IAM entities that are managed with this module, we need to make sure that
  # grants are created after the IAM entities. See: https://github.com/gruntwork-io/terraform-aws-architecture-catalog/issues/44.
  dependencies = concat(
    formatlist("%v", values(module.iam_cross_account_roles)),
    [
      for _, role in aws_iam_service_linked_role.role :
      role.id
    ],
  )
}

# ----------------------------------------------------------------------------------------------------------------------
# ELASTIC BLOCK STORAGE (EBS) ENCRYPTION DEFAULTS
# ----------------------------------------------------------------------------------------------------------------------

module "ebs_encryption" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/ebs-encryption-multi-region?ref=v0.46.4"

  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region
  opt_in_regions = var.ebs_opt_in_regions

  enable_encryption     = var.ebs_enable_encryption
  use_existing_kms_keys = var.ebs_use_existing_kms_keys

  # The KMS key name is supplied which will be in the output of CMKs created earlier, so use this
  # to create a map of region names against CMK ARNs for the EBS encryption key
  kms_key_arns = {
    for k, v in module.customer_master_keys.key_arns :
    k => lookup(v, var.ebs_kms_key_name, null)
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL SERVICE-LINKED ROLES
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_iam_service_linked_role" "role" {
  for_each         = var.service_linked_roles
  aws_service_name = each.value
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM ACCESS ANALYZER DEFAULTS
# ----------------------------------------------------------------------------------------------------------------------
module "iam_access_analyzer" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-access-analyzer-multi-region?ref=v0.45.3"

  aws_account_id = var.aws_account_id

  create_resources         = var.enable_iam_access_analyzer
  iam_access_analyzer_name = var.iam_access_analyzer_name
  iam_access_analyzer_type = var.iam_access_analyzer_type
  seed_region              = var.aws_region
  opt_in_regions           = var.iam_access_analyzer_opt_in_regions
}
