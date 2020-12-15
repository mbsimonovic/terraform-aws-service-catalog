# ----------------------------------------------------------------------------------------------------------------------
# SET UP AWS CONFIG AND CLOUDTRAIL S3 BUCKETS IN THE LOGS ACCOUNT
# Normally, we'd configure the logs account in its own account-baseline module, but since we want to aggregate all AWS
# Config and CloudTrail data in the logs account, including AWS Config and CloudTrail data from the root account, we
# need to set up the S3 buckets for that data now, from the root account. It's a bit weird to manage resources in
# one account from another, so we've extracted this part of the code into its own file to try to make that more clear.
# ----------------------------------------------------------------------------------------------------------------------

# Use a null_resource as an awkward mechanism to ensure that we wait for the child accounts to be created before trying
# to do anything in them (e.g., assume a role in them)
resource "null_resource" "wait_for_account_creation" {
  triggers = {
    logs_account_id = local.logs_account_id
  }

  provisioner "local-exec" {
    # We need a sleep 30 here to give the child accounts and the IAM roles within them time to be created
    command = "python -c 'import time; time.sleep(30)'"
  }
}

locals {
  # If the user marks one of the child accountss as the "logs" account, we create an S3 bucket in it for AWS Config and
  # an S3 bucket and KMS CMK in it for AWS CloudTrail, and configure the root account to send all AWS Config and
  # CloudTrail data to that account.
  logs_account_name_array = [for name, account in var.child_accounts : name if lookup(account, "is_logs_account", false)]
  has_logs_account        = length(local.logs_account_name_array) > 0
  logs_account_name       = local.has_logs_account ? local.logs_account_name_array[0] : null
  logs_account_role_name  = local.has_logs_account ? lookup(var.child_accounts[local.logs_account_name], "role_name", var.organizations_default_role_name) : null

  logs_account_id          = local.has_logs_account ? module.organization.child_accounts[local.logs_account_name].id : var.config_central_account_id
  non_logs_account_ids     = local.has_logs_account ? [for account in module.organization.child_accounts : account.id if account.name != local.logs_account_name] : [for account in module.organization.child_accounts : account.id if account.id != var.config_central_account_id]
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

# Workaround for Terraform limitation where you cannot directly set a depends on directive or interpolate from resources
# in the provider config.
# Specifically, Terraform requires all information for the Terraform provider config to be available at plan time,
# meaning there can be no computed resources. We work around this limitation by creating a template_file data source
# that does the computation.
# See https://github.com/hashicorp/terraform/issues/2430 for more details
data "template_file" "logs_account_iam_role_arn" {
  template = local.has_logs_account ? "arn:aws:iam::${null_resource.wait_for_account_creation.triggers.logs_account_id}:role/${local.logs_account_role_name}" : ""
}

provider "aws" {
  alias  = "logs"
  region = var.aws_region

  assume_role {
    # We intentionally depend on the null_resource here to ensure we give the child accounts and the IAM roles in them
    # enough time to be created and usable. Note that if the user has not specified a logs account, then we set
    # role_arn to null, so instead, this provider block will use the same (root) account as all the other resources.
    role_arn = local.has_logs_account ? data.template_file.logs_account_iam_role_arn.rendered : null
  }
}

module "config_bucket" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/aws-config-bucket?ref=v0.44.4"

  providers = {
    aws = aws.logs
  }

  create_resources = var.enable_config && var.config_should_create_s3_bucket

  # Create the S3 bucket and allow all the other accounts to write to this bucket
  s3_bucket_name  = local.config_s3_bucket_name_base
  linked_accounts = local.all_non_logs_account_ids

  # We have to set this to work around an issue where aws_caller_identity returns the wrong account ID. See:
  # https://github.com/gruntwork-io/module-security/pull/308#issuecomment-676561441
  current_account_id = local.has_logs_account ? local.logs_account_id : null

  force_destroy                         = var.config_force_destroy
  num_days_after_which_archive_log_data = var.config_num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.config_num_days_after_which_delete_log_data
  tags                                  = var.config_tags
}

module "cloudtrail_bucket" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/cloudtrail-bucket?ref=v0.44.4"

  providers = {
    aws = aws.logs
  }

  create_resources = var.enable_cloudtrail && var.cloudtrail_s3_bucket_already_exists == false

  # Create the S3 bucket and allow all the other accounts to write to this bcket
  s3_bucket_name                             = local.cloudtrail_s3_bucket_name_base
  external_aws_account_ids_with_write_access = local.all_non_logs_account_ids

  cloudtrail_trail_name = var.name_prefix

  kms_key_already_exists                          = var.cloudtrail_kms_key_arn != null
  kms_key_arn                                     = var.cloudtrail_kms_key_arn
  kms_key_administrator_iam_arns                  = local.cloudtrail_kms_key_administrator_iam_arns
  kms_key_user_iam_arns                           = var.cloudtrail_kms_key_user_iam_arns
  allow_kms_describe_key_to_external_aws_accounts = var.cloudtrail_allow_kms_describe_key_to_external_aws_accounts
  allow_cloudtrail_access_with_iam                = var.allow_cloudtrail_access_with_iam

  # We have to set this to work around an issue where aws_caller_identity returns the wrong account ID. See:
  # https://github.com/gruntwork-io/module-security/pull/308#issuecomment-676561441
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
  count = local.has_logs_account ? 1 : 0
  arn   = module.config_bucket.s3_bucket_arn
}

data "aws_arn" "cloudtrail_s3_bucket" {
  count = local.has_logs_account ? 1 : 0
  arn   = module.cloudtrail_bucket.s3_bucket_arn
}
