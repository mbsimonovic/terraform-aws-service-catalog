# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR SECURITY ACCOUNT
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

module "security_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-security"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  config_s3_bucket_name          = var.config_s3_bucket_name
  config_should_create_s3_bucket = var.config_should_create_s3_bucket
  config_central_account_id      = var.config_central_account_id

  cloudtrail_kms_key_arn                = var.cloudtrail_kms_key_arn
  cloudtrail_s3_bucket_already_exists   = var.cloudtrail_s3_bucket_already_exists
  cloudtrail_s3_bucket_name             = var.cloudtrail_s3_bucket_name
  cloudtrail_cloudwatch_logs_group_name = var.cloudtrail_cloudwatch_logs_group_name

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
}

data "aws_caller_identity" "current" {}
