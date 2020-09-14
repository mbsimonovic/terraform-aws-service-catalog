# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR ROOT ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that may have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.58"
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# ORGANIZATIONS MODULE AND CHILD ACCOUNTS
# ----------------------------------------------------------------------------------------------------------------------

module "organization" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-organizations?ref=v0.36.8"

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
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-config-multi-region?ref=v0.36.8"

  create_resources       = var.enable_config
  aws_account_id         = var.aws_account_id
  seed_region            = var.aws_region
  global_recorder_region = var.aws_region

  # Set to false here because we create the bucket using the aws-config-bucket module in the logs account
  should_create_s3_bucket = false
  s3_bucket_name          = local.config_s3_bucket_name_with_dependency

  force_destroy  = var.config_force_destroy
  opt_in_regions = var.config_opt_in_regions

  aggregate_config_data_in_external_account = local.has_logs_account ? true : var.config_aggregate_config_data_in_external_account
  central_account_id                        = null_resource.wait_for_account_creation.triggers.logs_account_id

  tags = var.config_tags
}

module "organizations_config_rules" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-config-rules?ref=v0.36.8"

  create_resources = var.enable_config

  // Make sure AWS Config has been applied first
  // Because `aws-config-multi-region` doesn't have a string or list of strings output, we'll construct one dynamically
  dependencies = concat([
    for k, v in module.config.config_sns_topic_arns :
    v
  ], values(module.config.config_recorder_names))

  additional_rules                         = var.additional_config_rules
  enable_encrypted_volumes                 = var.enable_encrypted_volumes
  enable_iam_password_policy               = var.enable_iam_password_policy
  enable_insecure_sg_rules                 = var.enable_insecure_sg_rules
  enable_rds_storage_encrypted             = var.enable_rds_storage_encrypted
  enable_root_account_mfa                  = var.enable_root_account_mfa
  enable_s3_bucket_public_read_prohibited  = var.enable_s3_bucket_public_read_prohibited
  enable_s3_bucket_public_write_prohibited = var.enable_s3_bucket_public_write_prohibited

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

  # We used to do org-level rules, but those have a dependency / ordering problem: if you enable org-level rules, they
  # immediately apply to ALL child accounts... But if a child account doesn't have a Config Recorder, it fails. So when
  # adding new child accounts, the deployment always fails, because of course brand new accounts don't have Config
  # Recorders. So we now default to account-level rules, whch means we have to apply the same rules in each and every
  # account, but we can ensure that the rules are only enforced after the Config Recorder is in place, so there's no
  # chicken-and-egg problem.
  create_account_rules = var.config_create_account_rules

  # If the user chooses to go with org-level Config rules after all, we make a best-effort attempt here to exclude new
  # child accounts by default (as they don't have a Config Recorder yet) and only include them if the user explicitly
  # tells us too (e.g., after having deployed a Config Recorder and come back to root to re-run apply). This is a
  # brittle, error-prone, multi-step deploy process, which is why we recommend account-level rules instead.
  excluded_accounts = local.all_excluded_child_accounts_ids
}

locals {
  # If the user chooses to use org-level config rules, we have to do some magic to exclude all the child accounts from
  # config rules initially, as they don't have any Config Recorders yet, and then allow the user to opt-in to enabling
  # config rules on an account-by-account basis afterwords.
  excluded_child_account_ids      = var.config_create_account_rules ? [] : [for account_name, account in module.organization.child_accounts : account.id if lookup(lookup(var.child_accounts, account_name, {}), "enable_config_rules", false) == false]
  all_excluded_child_accounts_ids = var.config_create_account_rules ? [] : toset(concat(var.configrules_excluded_accounts, local.excluded_child_account_ids))
}

# ----------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL
# ----------------------------------------------------------------------------------------------------------------------

module "cloudtrail" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cloudtrail?ref=v0.36.8"

  create_resources      = var.enable_cloudtrail
  cloudtrail_trail_name = var.name_prefix

  # Set to true here because we create the bucket using the cloudtrail-bucket module in the logs account
  s3_bucket_already_exists = true
  s3_bucket_name           = local.cloudtrail_s3_bucket_name_with_dependency

  # Set to true here because we create the KMS key using the cloudtrail-bucket module in the logs account
  kms_key_already_exists           = true
  kms_key_arn                      = local.cloudtrail_kms_key_arn_with_dependency
  allow_cloudtrail_access_with_iam = false

  # Configure the trail to publish logs to a CloudWatch Logs group within the current account.
  cloudwatch_logs_group_name = var.cloudtrail_cloudwatch_logs_group_name

  force_destroy = var.cloudtrail_force_destroy
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_groups" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-groups?ref=v0.36.8"

  aws_account_id     = var.aws_account_id
  should_require_mfa = var.should_require_mfa

  iam_group_developers_permitted_services = var.iam_group_developers_permitted_services

  iam_groups_for_cross_account_access = var.iam_groups_for_cross_account_access
  cross_account_access_all_group_name = var.cross_account_access_all_group_name

  should_create_iam_group_full_access            = var.should_create_iam_group_full_access
  should_create_iam_group_billing                = var.should_create_iam_group_billing
  should_create_iam_group_support                = var.should_create_iam_group_support
  should_create_iam_group_logs                   = var.should_create_iam_group_logs
  should_create_iam_group_developers             = var.should_create_iam_group_developers
  should_create_iam_group_read_only              = var.should_create_iam_group_read_only
  should_create_iam_group_user_self_mgmt         = var.should_create_iam_group_user_self_mgmt
  should_create_iam_group_use_existing_iam_roles = var.should_create_iam_group_use_existing_iam_roles
  should_create_iam_group_auto_deploy            = var.should_create_iam_group_auto_deploy
  should_create_iam_group_houston_cli_users      = var.should_create_iam_group_houston_cli_users

  auto_deploy_permissions = var.auto_deploy_permissions

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn_with_dependency
}

module "iam_users" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-users?ref=v0.36.8"

  users                   = var.users
  password_length         = var.iam_password_policy_minimum_password_length
  password_reset_required = var.password_reset_required

  force_destroy = var.force_destroy_users
}

module "iam_cross_account_roles" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cross-account-iam-roles?ref=v0.36.8"

  aws_account_id = var.aws_account_id

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

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn_with_dependency
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-user-password-policy?ref=v0.36.8"

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
  source         = "git::git@github.com:gruntwork-io/module-security.git//modules/guardduty-multi-region?ref=v0.36.8"
  aws_account_id = var.aws_account_id
  seed_region    = var.aws_region

  cloudwatch_event_rule_name   = var.guardduty_cloudwatch_event_rule_name
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency
  findings_sns_topic_name      = var.guardduty_findings_sns_topic_name
  opt_in_regions               = var.guardduty_opt_in_regions
  publish_findings_to_sns      = var.guardduty_publish_findings_to_sns
}
