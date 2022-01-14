


# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/jenkins?ref=v0.70.0"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/mgmt/jenkins"
}
# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------
dependency "vpc_mgmt" {
  config_path = "${get_terragrunt_dir()}/../networking/vpc"

  mock_outputs = {
    vpc_id             = "vpc-abcd1234"
    vpc_cidr_block     = "10.0.0.0/16"
    public_subnet_ids  = ["subnet-abcd1234", "subnet-bcd1234a", ]
    private_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "route53" {
  config_path = "${get_terragrunt_dir()}/../../../_global/route53-public"

  mock_outputs = {
    public_hosted_zone_map = {
      ("${local.account_vars.locals.domain_name.name}") = "some-zone"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "network_bastion" {
  config_path = "${get_terragrunt_dir()}/../networking/openvpn-server"

  mock_outputs = {
    security_group_id = "sg-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}


# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/jenkins"

  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name and account_role for easy access
  account_name = local.account_vars.locals.account_name
  account_role = local.account_vars.locals.account_role

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name          = "jenkins"
  instance_type = "t3.medium"
  memory        = "1024m"

  ami = ""
  ami_filters = {
    owners = [local.common_vars.locals.account_ids.shared]
    filters = [
      {
        name   = "name"
        values = ["jenkins-server-v0.70.0-*"]
      },
    ]
  }

  vpc_id            = dependency.vpc_mgmt.outputs.vpc_id
  jenkins_subnet_id = dependency.vpc_mgmt.outputs.private_subnet_ids[0]
  alb_subnet_ids    = dependency.vpc_mgmt.outputs.public_subnet_ids

  keypair_name                      = "jenkins-admin-v1"
  allow_ssh_from_cidr_blocks        = [dependency.vpc_mgmt.outputs.vpc_cidr_block]
  allow_ssh_from_security_group_ids = [dependency.network_bastion.outputs.security_group_id]

  enable_ssh_grunt                    = true
  ssh_grunt_iam_group                 = local.common_vars.locals.ssh_grunt_users_group
  ssh_grunt_iam_group_sudo            = local.common_vars.locals.ssh_grunt_sudo_users_group
  external_account_ssh_grunt_role_arn = local.common_vars.locals.allow_ssh_grunt_role

  is_internal_alb                             = true
  allow_incoming_http_from_cidr_blocks        = [dependency.vpc_mgmt.outputs.vpc_cidr_block]
  allow_incoming_http_from_security_group_ids = [dependency.network_bastion.outputs.security_group_id]

  hosted_zone_id             = dependency.route53.outputs.public_hosted_zone_map[local.account_vars.locals.domain_name.name]
  domain_name                = "jenkins.${local.account_vars.locals.domain_name.name}"
  acm_ssl_certificate_domain = local.account_vars.locals.domain_name.name

  ebs_kms_key_arn          = "arn:aws:kms:us-east-1:234567890123:alias/ExampleAMIEncryptionKMSKeyArn"
  ebs_kms_key_arn_is_alias = true

  external_account_auto_deploy_iam_role_arns = [
    for account, account_id in local.common_vars.locals.account_ids :
    "arn:aws:iam::${account_id}:role/allow-auto-deploy-from-other-accounts"
  ]

  jenkins_volume_encrypted = true
}