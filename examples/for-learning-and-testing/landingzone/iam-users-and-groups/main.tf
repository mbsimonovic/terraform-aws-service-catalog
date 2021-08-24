# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR SECURITY ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}


# ---------------------------------------------------------------------------------------------------------------------
# CALL THE IAM USERS AND GROUPS MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "iam_users_and_groups" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/iam-users-and-groups?ref=v1.0.0"
  source = "../../../../modules/landingzone/iam-users-and-groups"

  aws_account_id = data.aws_caller_identity.current.account_id

  users = {
    "${var.name_prefix}alice" = {
      groups             = ["${var.name_prefix}-full-access"]
      create_access_keys = false
    }
    "${var.name_prefix}bob" = {
      groups = ["${var.name_prefix}-read-only"]
      tags = {
        foo = "bar"
      }
    }
  }

  # Only create full-access and read-only IAM Groups
  should_create_iam_group_full_access    = true
  should_create_iam_group_read_only      = true
  should_create_iam_group_user_self_mgmt = false
  iam_group_name_full_access             = "${var.name_prefix}-full-access"
  iam_group_name_read_only               = "${var.name_prefix}-read-only"
  iam_policy_iam_user_self_mgmt          = "${var.name_prefix}-iam-user-self-mgmt"
  iam_group_names_ssh_grunt_sudo_users   = []
  iam_group_names_ssh_grunt_users        = []

  # These are variables you only need to set at test time so that everything can be deleted cleanly. You will likely
  # NOT need to set this in any real environments.
  force_destroy_users = var.force_destroy
}

data "aws_caller_identity" "current" {}
