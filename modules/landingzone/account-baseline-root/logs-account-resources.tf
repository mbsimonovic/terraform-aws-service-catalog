# ----------------------------------------------------------------------------------------------------------------------
# SET UP AWS CONFIG AND CLOUDTRAIL S3 BUCKETS IN THE LOGS ACCOUNT
# Normally, we'd configure the logs account in its own account-baseline module, but since we want to aggregate all AWS
# Config and CloudTrail data in the logs account, including AWS Config and CloudTrail data from the root account, we
# need to set up the S3 buckets for that data now, from the root account. It's a bit weird to manage resources in
# one account from another, so we've extracted this part of the code into its own file to try to make that more clear.
# ----------------------------------------------------------------------------------------------------------------------

# This data source is used to check if the logs account already exists. By not depending on the organization module,
# it can be used to correctly determine the logs account ID during a Terraform refresh.
data "aws_organizations_organization" "logs_account_id_exists" {
  count      = local.has_logs_account ? 1 : 0
  depends_on = [time_sleep.wait_30_seconds]
}

# This data source is used to find the logs account ID if the logs account does not yet exist. It depends on the
# organization to create an explicit dependency so that provider configuration below will not fail when attempting to
# assume an IAM role in the logs account before it is ready. We cannot use this data source if the account ID
# already exists because the data source will not refresh correctly, and subsequently the logs account ID
# will not be known, causing errors to occur. For more information, see:
#   https://github.com/hashicorp/terraform/pull/24904
#   https://github.com/gruntwork-io/terraform-aws-security/issues/421
data "aws_organizations_organization" "logs_account_id_does_not_exist" {
  count      = local.has_logs_account ? 1 : 0
  depends_on = [module.organization, time_sleep.wait_30_seconds]
}

# This time_sleep is triggered under two conditions:
#
#  - If the logs account exists.
#  - If the logs account does not exist.
#
# To explain further, if the Organization does NOT yet exist - e.g. the first run with create_organization=true
# - and a logs account exists in var.child_accounts, the first condition is met, the time_sleep is
# triggered, and the wait occurs, thus allowing the Organization and logs account to be created before the data
# source tries to look up the logs account.
#
# If the Organization does NOT yet exist, and a logs account ALSO does not exist in var.child_accounts, the second
# condition is met, and the time_sleep is triggered, the wait occurs, allowing the Organization to be created
# before the data source executes.
#
# Why not just trigger it with a string of "", you may ask? For the following reason: If the Organization _already_
# exists, and any child account (but not the logs account) already exists, then the time_sleep will also already
# exist, and hence will not trigger during a refresh phase or plan. But then if the user later adds a logs account,
# we need this time_sleep to trigger again, thus incurring the wait condition, and thus not failing to assume the
# role and cause all the other problems described in https://github.com/gruntwork-io/terraform-aws-security/issues/421.
resource "time_sleep" "wait_30_seconds" {
  triggers = {
    logs_account_name = length(local.logs_account_name_array) > 0 ? local.logs_account_name_array[0] : ""
  }

  create_duration = "30s"
}

locals {
  # If the user marks one of the child accounts as the "logs" account, we create an S3 bucket in it for AWS Config and
  # an S3 bucket and KMS CMK in it for AWS CloudTrail, and configure the root account to send all AWS Config and
  # CloudTrail data to that account.
  logs_account_name_array  = [for name, account in var.child_accounts : name if lookup(account, "is_logs_account", false)]
  has_logs_account         = length(local.logs_account_name_array) > 0
  logs_account_name        = local.has_logs_account ? local.logs_account_name_array[0] : null
  logs_account_email_array = [for name, account in var.child_accounts : account.email if lookup(account, "is_logs_account", false)]
  logs_account_email       = local.has_logs_account ? local.logs_account_email_array[0] : null
  logs_account_role_name   = local.has_logs_account ? lookup(var.child_accounts[local.logs_account_name], "role_name", var.organizations_default_role_name) : null

  # First, find out if the logs account already exists
  existing_logs_account_list = (
    local.has_logs_account ? (
      [
        for account in data.aws_organizations_organization.logs_account_id_exists[0].non_master_accounts
        : account.id
        if account.email == local.logs_account_email
      ]
    )
    : []
  )

  logs_account_id_exists = length(local.existing_logs_account_list) == 1 ? local.existing_logs_account_list[0] : null

  # If no matches were found, that must mean that we are creating a logs account for the first time, so use the other data source
  logs_account_id_new = (
    local.has_logs_account && local.logs_account_id_exists == null
    ? (
      [
        for account in data.aws_organizations_organization.logs_account_id_does_not_exist[0].non_master_accounts
        : account.id
        if account.email == local.logs_account_email
      ][0]
    )
    : var.config_central_account_id
  )

  # Finally, set the logs account ID based on the results of the previous searches.
  logs_account_id = (
    local.has_logs_account && local.logs_account_id_exists == null
    ? local.logs_account_id_new
    : local.logs_account_id_exists
  )

  non_logs_account_ids = (
    local.has_logs_account
    ? [
      for account in module.organization.child_accounts
      : account.id if account.email != local.logs_account_email
    ]
    : [
      for account in module.organization.child_accounts
      : account.id if account.id != var.config_central_account_id
    ]
  )

  all_non_logs_account_ids = concat(local.non_logs_account_ids, [module.organization.master_account_id])

  # If the user specified a logs account, include that account's root user ARN in the list of admins for the CloudTrail
  # KMS CMK. We have to include it automatically because (a) the user can't specify the logs account ID manually, as on
  # the initial apply, the account doesn't exist yet and (b) without the logs account root ARN in the list, we get an
  # error:
  #
  # "MalformedPolicyDocumentException: The new key policy will not allow you to update the key policy in the future."
  #
  # It seems that if you're creating a KMS CMK in account X, some user from that account must be an admin, or you get
  # this error. We have no other users in the logs account, so we go with the root user, which is common to include on
  # a CMK anyway as a fallback so you never lose access.
  logs_account_arn                          = local.has_logs_account ? "arn:aws:iam::${local.logs_account_id}:root" : ""
  cloudtrail_kms_key_administrator_iam_arns = local.has_logs_account ? toset(concat(var.cloudtrail_kms_key_administrator_iam_arns, [local.logs_account_arn])) : var.cloudtrail_kms_key_administrator_iam_arns
}

provider "aws" {
  alias  = "logs"
  region = var.aws_region

  assume_role {
    role_arn = local.has_logs_account && local.logs_account_id != "" ? "arn:aws:iam::${local.logs_account_id}:role/${local.logs_account_role_name}" : null
  }
}

module "config_bucket" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/aws-config-bucket?ref=v0.62.1"

  providers = {
    aws = aws.logs
  }

  create_resources = var.config_should_create_s3_bucket

  # Create the S3 bucket and allow all the other accounts to write to this bucket
  s3_bucket_name  = local.config_s3_bucket_name_base
  s3_mfa_delete   = var.config_s3_mfa_delete
  linked_accounts = local.all_non_logs_account_ids

  # We have to set this to work around an issue where aws_caller_identity returns the wrong account ID. See:
  # https://github.com/gruntwork-io/terraform-aws-security/pull/308#issuecomment-676561441
  current_account_id = local.has_logs_account ? local.logs_account_id : null

  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  tags                                  = var.config_tags

  kms_key_arn = var.config_s3_bucket_kms_key_arn
}

module "cloudtrail_bucket" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/cloudtrail-bucket?ref=v0.62.1"

  providers = {
    aws = aws.logs
  }

  create_resources = var.cloudtrail_should_create_s3_bucket

  # Create the S3 bucket and allow all the other accounts (or entire organization) to write to this bucket
  s3_bucket_name                             = local.cloudtrail_s3_bucket_name_base
  mfa_delete                                 = var.cloudtrail_s3_mfa_delete
  enable_s3_server_access_logging            = var.enable_cloudtrail_s3_server_access_logging
  external_aws_account_ids_with_write_access = local.all_non_logs_account_ids
  cloudtrail_trail_name                      = var.name_prefix
  organization_id = (
    var.create_organization && var.cloudtrail_organization_id == null
    ? module.organization.organization_id
    : var.cloudtrail_organization_id
  )

  kms_key_already_exists                          = var.cloudtrail_kms_key_arn != null
  kms_key_arn                                     = var.cloudtrail_kms_key_arn
  enable_key_rotation                             = var.cloudtrail_enable_key_rotation
  kms_key_administrator_iam_arns                  = local.cloudtrail_kms_key_administrator_iam_arns
  kms_key_user_iam_arns                           = var.cloudtrail_kms_key_user_iam_arns
  allow_kms_describe_key_to_external_aws_accounts = var.cloudtrail_allow_kms_describe_key_to_external_aws_accounts
  allow_cloudtrail_access_with_iam                = var.allow_cloudtrail_access_with_iam

  # We have to set this to work around an issue where aws_caller_identity returns the wrong account ID. See:
  # https://github.com/gruntwork-io/terraform-aws-security/pull/308#issuecomment-676561441
  current_account_id = local.has_logs_account ? local.logs_account_id : null

  force_destroy                         = var.cloudtrail_force_destroy
  num_days_after_which_archive_log_data = var.cloudtrail_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.cloudtrail_num_days_after_which_delete_log_data
  tags                                  = var.cloudtrail_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# EXTRACT AWS CONFIG AND CLOUDTRAIL DATA AND CREATE A DEPENDENCY CHAIN
# We explicitly depend on the ARNs of these S3 buckets and KMS keys to create a dependency chain that ensures we don't
# try to use these resources until AFTER they have been created. E.g., To ensure the root account doesn't try to start
# writing AWS Config or CloudTrail data until after the logs account has been created and we've created S3 buckets
# and KMS keys in that logs account.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  config_s3_bucket_name_base     = var.config_s3_bucket_name != null ? var.config_s3_bucket_name : "${var.name_prefix}-logs-config"
  cloudtrail_s3_bucket_name_base = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : "${var.name_prefix}-cloudtrail"

  config_s3_bucket_name_with_dependency     = length(data.aws_arn.config_s3_bucket) > 0 ? data.aws_arn.config_s3_bucket[0].resource : local.config_s3_bucket_name_base
  cloudtrail_s3_bucket_name_with_dependency = length(data.aws_arn.cloudtrail_s3_bucket) > 0 ? data.aws_arn.cloudtrail_s3_bucket[0].resource : local.cloudtrail_s3_bucket_name_base
  cloudtrail_kms_key_arn_with_dependency    = local.has_logs_account ? module.cloudtrail_bucket.kms_key_arn : var.cloudtrail_kms_key_arn
}

data "aws_arn" "config_s3_bucket" {
  count = var.config_should_create_s3_bucket ? 1 : 0
  arn   = module.config_bucket.s3_bucket_arn
}

data "aws_arn" "cloudtrail_s3_bucket" {
  count = var.cloudtrail_should_create_s3_bucket ? 1 : 0
  arn   = module.cloudtrail_bucket.s3_bucket_arn
}
