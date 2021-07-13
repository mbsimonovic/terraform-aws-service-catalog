# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IAM USERS AND IAM GROUPS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.58"
    }
  }
}

module "iam_groups" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-groups?ref=v0.50.1"

  create_resources = var.enable_iam_groups

  aws_account_id     = var.aws_account_id
  should_require_mfa = var.should_require_mfa

  iam_group_developers_permitted_services = var.iam_group_developers_permitted_services

  iam_groups_for_cross_account_access = var.iam_groups_for_cross_account_access
  cross_account_access_all_group_name = var.cross_account_access_all_group_name

  should_create_iam_group_full_access              = var.should_create_iam_group_full_access
  should_create_iam_group_billing                  = var.should_create_iam_group_billing
  should_create_iam_group_support                  = var.should_create_iam_group_support
  should_create_iam_group_logs                     = var.should_create_iam_group_logs
  should_create_iam_group_developers               = var.should_create_iam_group_developers
  should_create_iam_group_read_only                = var.should_create_iam_group_read_only
  should_create_iam_group_user_self_mgmt           = var.should_create_iam_group_user_self_mgmt
  should_create_iam_group_iam_admin                = var.should_create_iam_group_iam_admin
  should_create_iam_group_use_existing_iam_roles   = var.should_create_iam_group_use_existing_iam_roles
  should_create_iam_group_auto_deploy              = var.should_create_iam_group_auto_deploy
  should_create_iam_group_houston_cli_users        = var.should_create_iam_group_houston_cli_users
  should_create_iam_group_cross_account_access_all = var.should_create_iam_group_cross_account_access_all

  iam_group_name_full_access            = var.iam_group_name_full_access
  iam_group_name_billing                = var.iam_group_name_billing
  iam_group_name_support                = var.iam_group_name_support
  iam_group_name_logs                   = var.iam_group_name_logs
  iam_group_name_developers             = var.iam_group_name_developers
  iam_group_name_read_only              = var.iam_group_name_read_only
  iam_group_names_ssh_grunt_sudo_users  = var.iam_group_names_ssh_grunt_sudo_users
  iam_group_names_ssh_grunt_users       = var.iam_group_names_ssh_grunt_users
  iam_group_name_use_existing_iam_roles = var.iam_group_name_use_existing_iam_roles
  iam_group_name_auto_deploy            = var.iam_group_name_auto_deploy
  iam_group_name_houston_cli            = var.iam_group_name_houston_cli
  iam_group_name_iam_user_self_mgmt     = var.iam_group_name_iam_user_self_mgmt
  iam_policy_iam_user_self_mgmt         = var.iam_policy_iam_user_self_mgmt
  iam_group_name_iam_admin              = var.iam_group_name_iam_admin
  auto_deploy_permissions               = var.auto_deploy_permissions

  cloudtrail_kms_key_arn = var.cloudtrail_kms_key_arn
}

module "iam_users" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-users?ref=v0.50.1"

  users                   = var.users
  password_length         = var.minimum_password_length
  password_reset_required = var.password_reset_required

  force_destroy = var.force_destroy_users

  # By default we only create the admin and cross account groups in the security account
  # NOTE: If other groups are referenced, it might lead to an error. This could be avoided if the `iam_groups` -module
  #       would provide a list output with all IAM Groups.
  dependencies = [module.iam_groups.iam_admin_iam_group_arn, element(concat(module.iam_groups.cross_account_access_group_arns, [""]), 0)]
}

