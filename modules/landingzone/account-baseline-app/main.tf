# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ACCOUNT BASELINE WRAPPER FOR APP ACCOUNTS
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
# AWS CONFIG
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

  s3_bucket_name          = var.config_s3_bucket_name != null ? var.config_s3_bucket_name : "${var.name_prefix}-config"
  should_create_s3_bucket = var.config_should_create_s3_bucket
  s3_mfa_delete           = var.config_s3_mfa_delete
  sns_topic_name          = var.config_sns_topic_name
  should_create_sns_topic = var.config_should_create_sns_topic

  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  opt_in_regions                        = var.config_opt_in_regions

  linked_accounts                           = var.config_linked_accounts
  aggregate_config_data_in_external_account = var.config_aggregate_config_data_in_external_account
  central_account_id                        = var.config_central_account_id

  s3_bucket_kms_key_arn = local.config_s3_bucket_kms_key_arn
  sns_topic_kms_key_region_map = (
    length(local.config_sns_topic_kms_key_arn_region_map) > 0
    ? local.config_sns_topic_kms_key_arn_region_map
    : null
  )
  delivery_channel_kms_key_arn = local.config_delivery_channel_kms_key_arn

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

locals {
  # If the KMS Key is provided by name, look up the ARN from the result of the module call to kms-master-key-multi-region.
  config_sns_topic_kms_key_arn_region_map = merge(
    (
      var.config_sns_topic_kms_key_by_name_region_map != null
      ? {
        for region, name in var.config_sns_topic_kms_key_by_name_region_map :
        region => module.customer_master_keys.key_arns[region][name]
      }
      : {}
    ),
    # Use merge so that var.config_sns_topic_kms_key_region_map wins out in the end
    (
      var.config_sns_topic_kms_key_region_map != null
      ? var.config_sns_topic_kms_key_region_map
      : {}
    ),
  )
  config_s3_bucket_kms_key_arn = (
    var.config_s3_bucket_kms_key_arn != null
    ? var.config_s3_bucket_kms_key_arn
    : (
      var.config_s3_bucket_kms_key_by_name != null
      ? module.customer_master_keys.key_arns[var.aws_region][var.config_s3_bucket_kms_key_by_name]
      : null
    )
  )
  config_delivery_channel_kms_key_arn = (
    var.config_delivery_channel_kms_key_arn != null
    ? var.config_delivery_channel_kms_key_arn
    : (
      var.config_delivery_channel_kms_key_by_name != null
      ? module.customer_master_keys.key_arns[var.config_delivery_channel_kms_key_by_name.region][var.config_delivery_channel_kms_key_by_name.name]
      : null
    )
  )
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM MODULES
# ----------------------------------------------------------------------------------------------------------------------

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
  cloudtrail_kms_key_arn                    = module.cloudtrail.kms_key_arn

  allow_auto_deploy_from_github_actions = (
    var.enable_github_actions_access && length(var.allow_auto_deploy_from_github_actions_for_sources) > 0
    ? {
      openid_connect_provider_arn = concat(aws_iam_openid_connect_provider.github_actions.*.arn, [""])[0]
      openid_connect_provider_url = concat(aws_iam_openid_connect_provider.github_actions.*.url, [""])[0]
      allowed_sources             = var.allow_auto_deploy_from_github_actions_for_sources
    }
    : null
  )

  max_session_duration_human_users   = var.max_session_duration_human_users
  max_session_duration_machine_users = var.max_session_duration_machine_users
}

module "iam_user_password_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-user-password-policy?ref=v0.62.3"

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
# CLOUDTRAIL
# ----------------------------------------------------------------------------------------------------------------------

module "cloudtrail" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cloudtrail?ref=v0.62.3"

  create_resources      = var.enable_cloudtrail
  is_multi_region_trail = true
  cloudtrail_trail_name = (
    var.custom_cloudtrail_trail_name != null
    ? var.custom_cloudtrail_trail_name
    : var.name_prefix
  )
  s3_bucket_name = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : "${var.name_prefix}-cloudtrail"
  s3_mfa_delete  = var.cloudtrail_s3_mfa_delete
  tags           = var.cloudtrail_tags

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
  cloudwatch_logs_group_name         = var.cloudtrail_cloudwatch_logs_group_name
  num_days_to_retain_cloudwatch_logs = var.cloudtrail_num_days_to_retain_cloudwatch_logs

  # Optionally configure logging of data events
  data_logging_enabled                   = var.cloudtrail_data_logging_enabled
  data_logging_read_write_type           = var.cloudtrail_data_logging_read_write_type
  data_logging_include_management_events = var.cloudtrail_data_logging_include_management_events
  data_logging_resources                 = var.cloudtrail_data_logging_resources

  force_destroy = var.cloudtrail_force_destroy
}

# ----------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL KMS CMKS
# ----------------------------------------------------------------------------------------------------------------------

module "customer_master_keys" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-master-key-multi-region?ref=v0.62.3"

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

  customer_master_keys = var.kms_customer_master_keys
  global_tags          = var.kms_cmk_global_tags
  opt_in_regions       = var.kms_cmk_opt_in_regions
}

module "kms_grants" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-grant-multi-region?ref=v0.62.3"

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

  aws_account_id    = var.aws_account_id
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
