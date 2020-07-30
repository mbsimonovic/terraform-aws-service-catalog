# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR APP ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CALL THE BASELINE MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "app_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-app"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns
  allow_auto_deploy_from_other_account_arns      = var.allow_auto_deploy_from_other_account_arns

  auto_deploy_permissions = var.auto_deploy_permissions
  dev_permitted_services  = var.dev_permitted_services

  cloudtrail_s3_bucket_name = var.cloudtrail_s3_bucket_name
  cloudtrail_kms_key_arn    = module.cloudtrail_cmk.key_arn[local.cloudtrail_cmk_name]

  # Create a single global CMK for general use in the account
  kms_customer_master_keys = {
    account-default-cmk = {
      region                                = var.aws_region
      cmk_administrator_iam_arns            = var.kms_cmk_administrator_iam_arns
      cmk_user_iam_arns                     = []
      cmk_external_user_iam_arns            = []
      allow_manage_key_permissions_with_iam = false
    }
  }
}

# Create a dedicated KMS key for use with cloudtrail
module "cloudtrail_cmk" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key?ref=v0.32.1"
  customer_master_keys = {
    (local.cloudtrail_cmk_name) = {
      cmk_administrator_iam_arns = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:root"]
      cmk_user_iam_arns          = []
      cmk_service_principals = [
        {
          name    = "cloudtrail.amazonaws.com"
          actions = ["kms:GenerateDataKey*"]
          conditions = [{
            test     = "StringLike"
            variable = "kms:EncryptionContext:aws:cloudtrail:arn"
            values = concat([
              "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}"
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
}

locals {
  cloudtrail_cmk_name = "cmk-${var.name_prefix}-cloudtrail"
}

data "aws_caller_identity" "current" {}
