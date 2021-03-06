# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR ROOT ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
      version = ">= 2.58, < 4.0"
      configuration_aliases = [
        aws.af_south_1,
        aws.ap_east_1,
        aws.ap_northeast_1,
        aws.ap_northeast_2,
        aws.ap_northeast_3,
        aws.ap_south_1,
        aws.ap_southeast_1,
        aws.ap_southeast_2,
        aws.ap_southeast_3,
        aws.ca_central_1,
        aws.cn_north_1,
        aws.cn_northwest_1,
        aws.eu_central_1,
        aws.eu_north_1,
        aws.eu_south_1,
        aws.eu_west_1,
        aws.eu_west_2,
        aws.eu_west_3,
        aws.me_south_1,
        aws.sa_east_1,
        aws.us_east_1,
        aws.us_east_2,
        aws.us_gov_east_1,
        aws.us_gov_west_1,
        aws.us_west_1,
        aws.us_west_2,
        # This is the default region to use for resources that deploy to just one region. Note that the underlying
        # module expects a named provider even though it's the default one. This ensures that we explicitly set to
        # exactly what we need, rather than having an implicit one get used accidentally. All the providers below this
        # one are regional.
        aws.default,
      ]
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# ORGANIZATIONS MODULE AND CHILD ACCOUNTS
# ----------------------------------------------------------------------------------------------------------------------

module "organization" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/aws-organizations?ref=v0.62.3"

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
# AWS CONFIG AND CONFIG RULES
# We send AWS Config data to the S3 bucket in the logs account
# ----------------------------------------------------------------------------------------------------------------------

module "config" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/aws-config-multi-region?ref=v0.62.3"

  # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
  # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
  # regions that are enabled in your AWS account.
  providers = {
    aws.af_south_1     = aws.af_south_1
    aws.ap_east_1      = aws.ap_east_1
    aws.ap_northeast_1 = aws.ap_northeast_1
    aws.ap_northeast_2 = aws.ap_northeast_2
    aws.ap_northeast_3 = aws.ap_northeast_3
    aws.ap_south_1     = aws.ap_south_1
    aws.ap_southeast_1 = aws.ap_southeast_1
    aws.ap_southeast_2 = aws.ap_southeast_2
    aws.ap_southeast_3 = aws.ap_southeast_3
    aws.ca_central_1   = aws.ca_central_1
    aws.cn_north_1     = aws.cn_north_1
    aws.cn_northwest_1 = aws.cn_northwest_1
    aws.eu_central_1   = aws.eu_central_1
    aws.eu_north_1     = aws.eu_north_1
    aws.eu_south_1     = aws.eu_south_1
    aws.eu_west_1      = aws.eu_west_1
    aws.eu_west_2      = aws.eu_west_2
    aws.eu_west_3      = aws.eu_west_3
    aws.me_south_1     = aws.me_south_1
    aws.sa_east_1      = aws.sa_east_1
    aws.us_east_1      = aws.us_east_1
    aws.us_east_2      = aws.us_east_2
    aws.us_gov_east_1  = aws.us_gov_east_1
    aws.us_gov_west_1  = aws.us_gov_west_1
    aws.us_west_1      = aws.us_west_1
    aws.us_west_2      = aws.us_west_2
    aws.default        = aws.default
  }

  create_resources       = var.enable_config
  aws_account_id         = var.aws_account_id
  global_recorder_region = var.aws_region

  # Set to false here because we create the bucket using the aws-config-bucket module in the logs account
  should_create_s3_bucket = false
  s3_bucket_name          = local.config_s3_bucket_name_with_dependency
  sns_topic_name          = var.config_sns_topic_name
  should_create_sns_topic = var.config_should_create_sns_topic

  sns_topic_kms_key_region_map = var.config_sns_topic_kms_key_region_map
  delivery_channel_kms_key_arn = (
    var.config_should_create_s3_bucket
    ? var.config_s3_bucket_kms_key_arn
    : var.config_delivery_channel_kms_key_arn
  )

  force_destroy  = var.config_force_destroy
  opt_in_regions = var.config_opt_in_regions

  aggregate_config_data_in_external_account = local.has_logs_account ? true : var.config_aggregate_config_data_in_external_account
  central_account_id                        = local.has_logs_account ? local.logs_account_id : var.config_central_account_id

  tags = var.config_tags

  #### Parameters for AWS Config Rules ####
  enable_config_rules                           = true
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
  create_account_rules = var.config_create_account_rules

  # If the user chooses to go with org-level Config rules after all, we make a best-effort attempt here to exclude new
  # child accounts by default (as they don't have a Config Recorder yet) and only include them if the user explicitly
  # tells us too (e.g., after having deployed a Config Recorder and come back to root to re-run apply). This is a
  # brittle, error-prone, multi-step deploy process, which is why we recommend account-level rules instead.
  config_rule_excluded_accounts = local.all_excluded_child_accounts_ids
}

locals {
  # If the user chooses to use org-level config rules, we have to do some magic to exclude all the child accounts from
  # config rules initially, as they don't have any Config Recorders yet, and then allow the user to opt-in to enabling
  # config rules on an account-by-account basis afterwords.
  excluded_child_account_ids = (
    var.config_create_account_rules
    ? []
    : [
      for account_name, account in module.organization.child_accounts
      : account.id
      if lookup(lookup(var.child_accounts, account_name, {}), "enable_config_rules", false) == false
    ]
  )
  all_excluded_child_accounts_ids = (
    var.config_create_account_rules
    ? []
    : toset(concat(var.configrules_excluded_accounts, local.excluded_child_account_ids))
  )
}

# ----------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL
# ----------------------------------------------------------------------------------------------------------------------

module "cloudtrail" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cloudtrail?ref=v0.62.3"

  create_resources      = var.enable_cloudtrail
  is_multi_region_trail = var.is_multi_region_trail
  cloudtrail_trail_name = var.name_prefix
  tags                  = var.cloudtrail_tags

  # Set to true here because we create the bucket using the cloudtrail-bucket module in the logs account
  s3_bucket_already_exists = true
  s3_bucket_name           = local.cloudtrail_s3_bucket_name_with_dependency

  # Set to true here because we create the KMS key using the cloudtrail-bucket module in the logs account
  kms_key_already_exists           = true
  kms_key_arn                      = local.cloudtrail_kms_key_arn_with_dependency
  kms_key_arn_is_alias             = var.cloudtrail_kms_key_arn_is_alias
  allow_cloudtrail_access_with_iam = false

  # Configure the trail to publish logs to a CloudWatch Logs group within the current account.
  cloudwatch_logs_group_name         = var.cloudtrail_cloudwatch_logs_group_name
  num_days_to_retain_cloudwatch_logs = var.cloudtrail_num_days_to_retain_cloudwatch_logs

  # Optionally configure the trail to be organization wide, in order to collect trails from all child accounts.
  is_organization_trail = var.cloudtrail_is_organization_trail

  # Optionally configure logging of data events
  data_logging_enabled                   = var.cloudtrail_data_logging_enabled
  data_logging_read_write_type           = var.cloudtrail_data_logging_read_write_type
  data_logging_include_management_events = var.cloudtrail_data_logging_include_management_events
  data_logging_resources                 = var.cloudtrail_data_logging_resources

  force_destroy = var.cloudtrail_force_destroy
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

module "iam_groups" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-groups?ref=v0.62.3"

  aws_account_id     = var.aws_account_id
  should_require_mfa = var.should_require_mfa

  create_resources = var.enable_iam_groups

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

  iam_group_names_ssh_grunt_sudo_users = var.iam_group_names_ssh_grunt_sudo_users
  iam_group_names_ssh_grunt_users      = var.iam_group_names_ssh_grunt_users
  auto_deploy_permissions              = var.auto_deploy_permissions

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn_with_dependency
}

module "iam_users" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-users?ref=v0.62.3"

  users                   = var.users
  password_length         = var.iam_password_policy_minimum_password_length
  password_reset_required = var.password_reset_required

  force_destroy = var.force_destroy_users
}

module "iam_cross_account_roles" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cross-account-iam-roles?ref=v0.62.3"

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

  cloudtrail_kms_key_arn = local.cloudtrail_kms_key_arn_with_dependency

  allow_auto_deploy_from_github_actions = (
    var.enable_github_actions_access && length(var.allow_auto_deploy_from_github_actions_for_sources) > 0
    ? {
      openid_connect_provider_arn = concat(aws_iam_openid_connect_provider.github_actions.*.arn, [""])[0]
      openid_connect_provider_url = concat(aws_iam_openid_connect_provider.github_actions.*.url, [""])[0]
      allowed_sources             = var.allow_auto_deploy_from_github_actions_for_sources
    }
    : null
  )
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-user-password-policy?ref=v0.62.3"

  create_resources = var.enable_iam_password_policy

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/guardduty-multi-region?ref=v0.62.3"

  # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
  # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
  # regions that are enabled in your AWS account.
  providers = {
    aws.af_south_1     = aws.af_south_1
    aws.ap_east_1      = aws.ap_east_1
    aws.ap_northeast_1 = aws.ap_northeast_1
    aws.ap_northeast_2 = aws.ap_northeast_2
    aws.ap_northeast_3 = aws.ap_northeast_3
    aws.ap_south_1     = aws.ap_south_1
    aws.ap_southeast_1 = aws.ap_southeast_1
    aws.ap_southeast_2 = aws.ap_southeast_2
    aws.ap_southeast_3 = aws.ap_southeast_3
    aws.ca_central_1   = aws.ca_central_1
    aws.cn_north_1     = aws.cn_north_1
    aws.cn_northwest_1 = aws.cn_northwest_1
    aws.eu_central_1   = aws.eu_central_1
    aws.eu_north_1     = aws.eu_north_1
    aws.eu_south_1     = aws.eu_south_1
    aws.eu_west_1      = aws.eu_west_1
    aws.eu_west_2      = aws.eu_west_2
    aws.eu_west_3      = aws.eu_west_3
    aws.me_south_1     = aws.me_south_1
    aws.sa_east_1      = aws.sa_east_1
    aws.us_east_1      = aws.us_east_1
    aws.us_east_2      = aws.us_east_2
    aws.us_gov_east_1  = aws.us_gov_east_1
    aws.us_gov_west_1  = aws.us_gov_west_1
    aws.us_west_1      = aws.us_west_1
    aws.us_west_2      = aws.us_west_2
  }

  aws_account_id = var.aws_account_id

  cloudwatch_event_rule_name   = var.guardduty_cloudwatch_event_rule_name
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency
  findings_sns_topic_name      = var.guardduty_findings_sns_topic_name
  opt_in_regions               = var.guardduty_opt_in_regions
  publish_findings_to_sns      = var.guardduty_publish_findings_to_sns
}

# ----------------------------------------------------------------------------------------------------------------------
# ELASTIC BLOCK STORAGE (EBS) ENCRYPTION DEFAULTS
# ----------------------------------------------------------------------------------------------------------------------

module "ebs_encryption" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/ebs-encryption-multi-region?ref=v0.62.3"

  # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
  # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
  # regions that are enabled in your AWS account.
  providers = {
    aws.af_south_1     = aws.af_south_1
    aws.ap_east_1      = aws.ap_east_1
    aws.ap_northeast_1 = aws.ap_northeast_1
    aws.ap_northeast_2 = aws.ap_northeast_2
    aws.ap_northeast_3 = aws.ap_northeast_3
    aws.ap_south_1     = aws.ap_south_1
    aws.ap_southeast_1 = aws.ap_southeast_1
    aws.ap_southeast_2 = aws.ap_southeast_2
    aws.ap_southeast_3 = aws.ap_southeast_3
    aws.ca_central_1   = aws.ca_central_1
    aws.cn_north_1     = aws.cn_north_1
    aws.cn_northwest_1 = aws.cn_northwest_1
    aws.eu_central_1   = aws.eu_central_1
    aws.eu_north_1     = aws.eu_north_1
    aws.eu_south_1     = aws.eu_south_1
    aws.eu_west_1      = aws.eu_west_1
    aws.eu_west_2      = aws.eu_west_2
    aws.eu_west_3      = aws.eu_west_3
    aws.me_south_1     = aws.me_south_1
    aws.sa_east_1      = aws.sa_east_1
    aws.us_east_1      = aws.us_east_1
    aws.us_east_2      = aws.us_east_2
    aws.us_gov_east_1  = aws.us_gov_east_1
    aws.us_gov_west_1  = aws.us_gov_west_1
    aws.us_west_1      = aws.us_west_1
    aws.us_west_2      = aws.us_west_2
  }

  aws_account_id = var.aws_account_id
  opt_in_regions = var.ebs_opt_in_regions

  enable_encryption = var.ebs_enable_encryption

  # For the root account we do not create keys by default. However, through these variables we expose
  # the configuration to permit custom keys if desired.
  use_existing_kms_keys = var.ebs_use_existing_kms_keys
  kms_key_arns          = var.ebs_kms_key_arns
}

# ----------------------------------------------------------------------------------------------------------------------
# EXTERNAL IAM ACCESS VIA OPENID CONNECT PROVIDERS
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  count          = var.enable_github_actions_access ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = (
    var.github_actions_openid_connect_provider_thumbprint_list != null
    ? var.github_actions_openid_connect_provider_thumbprint_list
    : [data.tls_certificate.oidc_thumbprint[0].certificates[0].sha1_fingerprint]
  )
}

data "tls_certificate" "oidc_thumbprint" {
  count = (
    var.enable_github_actions_access && var.github_actions_openid_connect_provider_thumbprint_list == null
    ? 1 : 0
  )
  url = "https://token.actions.githubusercontent.com"
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM ACCESS ANALYZER DEFAULTS
# ----------------------------------------------------------------------------------------------------------------------
module "iam_access_analyzer" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-access-analyzer-multi-region?ref=v0.62.3"

  # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
  # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
  # regions that are enabled in your AWS account.
  providers = {
    aws.af_south_1     = aws.af_south_1
    aws.ap_east_1      = aws.ap_east_1
    aws.ap_northeast_1 = aws.ap_northeast_1
    aws.ap_northeast_2 = aws.ap_northeast_2
    aws.ap_northeast_3 = aws.ap_northeast_3
    aws.ap_south_1     = aws.ap_south_1
    aws.ap_southeast_1 = aws.ap_southeast_1
    aws.ap_southeast_2 = aws.ap_southeast_2
    aws.ap_southeast_3 = aws.ap_southeast_3
    aws.ca_central_1   = aws.ca_central_1
    aws.cn_north_1     = aws.cn_north_1
    aws.cn_northwest_1 = aws.cn_northwest_1
    aws.eu_central_1   = aws.eu_central_1
    aws.eu_north_1     = aws.eu_north_1
    aws.eu_south_1     = aws.eu_south_1
    aws.eu_west_1      = aws.eu_west_1
    aws.eu_west_2      = aws.eu_west_2
    aws.eu_west_3      = aws.eu_west_3
    aws.me_south_1     = aws.me_south_1
    aws.sa_east_1      = aws.sa_east_1
    aws.us_east_1      = aws.us_east_1
    aws.us_east_2      = aws.us_east_2
    aws.us_gov_east_1  = aws.us_gov_east_1
    aws.us_gov_west_1  = aws.us_gov_west_1
    aws.us_west_1      = aws.us_west_1
    aws.us_west_2      = aws.us_west_2
  }

  aws_account_id = var.aws_account_id

  create_resources         = var.enable_iam_access_analyzer
  iam_access_analyzer_name = var.iam_access_analyzer_name
  iam_access_analyzer_type = var.iam_access_analyzer_type
  opt_in_regions           = var.iam_access_analyzer_opt_in_regions
}
