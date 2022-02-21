# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}


provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE GRUNTWORK ACCESS IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------

module "gruntwork_access" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/gruntwork-access?ref=v1.0.0"
  source = "../../../../modules/landingzone/gruntwork-access"

  # Grant admin access to the IAM role, and require the Gruntwork team to use MFA to assume the IAM role
  managed_policy_name = "AdministratorAccess"
  require_mfa         = true

  # To keep this example simple, we are NOT granting any other account access, but for a real Ref Arch deploy, you would
  # set grant_security_account_access to true and specify the ID of your security account via security_account_id.
  grant_security_account_access = false
  security_account_id           = null

  # For a Ref Arch deploy, you should always leave this IAM role at its default name. We only override it here for the
  # purposes of automated testing.
  iam_role_name = var.iam_role_name
}