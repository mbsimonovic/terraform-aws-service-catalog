# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR SECURITY ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CALL THE BASELINE MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "security_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-security"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  # We assume the S3 bucket for AWS Config has already been created by account-baseline-root
  config_should_create_s3_bucket                   = false
  config_s3_bucket_name                            = var.config_s3_bucket_name
  config_central_account_id                        = var.config_central_account_id
  config_aggregate_config_data_in_external_account = true

  # We assume the S3 bucket and KMS key for CloudTrail have already been created by account-baseline-root
  cloudtrail_s3_bucket_already_exists = true
  cloudtrail_kms_key_arn              = var.cloudtrail_kms_key_arn
  cloudtrail_s3_bucket_name           = var.cloudtrail_s3_bucket_name

  users = {
    alice = {
      groups             = ["full-access"]
      create_access_keys = false
    }
    bob = {
      groups = ["ssh-grunt-sudo-users"]
      tags = {
        foo = "bar"
      }
    }
  }

  # These are variables you only need to set at test time so that everything can be deleted cleanly. You will likely
  # NOT need to set this in any real environments.
  force_destroy_users      = var.force_destroy
  cloudtrail_force_destroy = var.force_destroy
  config_force_destroy     = var.force_destroy

  # Enable IAM Access Analyzer
  iam_access_analyzer_type   = var.iam_access_analyzer_type
  iam_access_analyzer_name   = var.iam_access_analyzer_name
  enable_iam_access_analyzer = var.enable_iam_access_analyzer
}

data "aws_caller_identity" "current" {}