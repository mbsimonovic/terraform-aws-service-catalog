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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/ecs-cluster?ref=v0.62.0"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/services/ecs-cluster"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                         = "vpc-abcd1234"
    private_app_subnet_ids         = ["subnet-abcd1234", "subnet-bcd1234a", ]
    private_app_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "network_bastion" {
  config_path = "${get_terragrunt_dir()}/../../networking/openvpn-server"

  mock_outputs = {
    security_group_id = "sg-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "sns" {
  config_path = "${get_terragrunt_dir()}/../../../_regional/sns-topic"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:123456789012:mytopic-NZJ5JSMVGFIE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "alb" {
  config_path = "${get_terragrunt_dir()}/../../networking/alb"

  mock_outputs = {
    alb_security_group_id = "sg-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "alb_internal" {
  config_path = "${get_terragrunt_dir()}/../../networking/alb-internal"

  mock_outputs = {
    alb_security_group_id = "sg-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}





# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
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
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  cluster_name          = "${local.name_prefix}-${local.account_name}"
  cluster_min_size      = 1
  cluster_max_size      = 2
  cluster_instance_type = "t3.micro"
  cluster_instance_ami  = ""
  cluster_instance_ami_filters = {
    owners = [local.common_vars.locals.accounts["shared"]]
    filters = [
      {
        name   = "name"
        values = ["ecs-cluster-instance-v0.62.0-*"]
      },
    ]
  }

  # We deploy ECS into the app VPC, inside the private app tier.
  vpc_id         = dependency.vpc.outputs.vpc_id
  vpc_subnet_ids = dependency.vpc.outputs.private_app_subnet_ids

  public_alb_sg_ids   = [dependency.alb.outputs.alb_security_group_id]
  internal_alb_sg_ids = [dependency.alb_internal.outputs.alb_security_group_id]

  cluster_instance_keypair_name = "ecs-cluster-admin-v1"

  allow_ssh_from_cidr_blocks        = dependency.vpc.outputs.private_app_subnet_cidr_blocks
  allow_ssh_from_security_group_ids = [dependency.network_bastion.outputs.security_group_id]

  enable_ssh_grunt                    = true
  ssh_grunt_iam_group                 = local.common_vars.locals.ssh_grunt_users_group
  ssh_grunt_iam_group_sudo            = local.common_vars.locals.ssh_grunt_sudo_users_group
  external_account_ssh_grunt_role_arn = local.common_vars.locals.allow_ssh_grunt_role

  # Aggregate logs in CloudWatch for debugging purposes
  enable_cloudwatch_log_aggregation = true

  enable_ecs_cloudwatch_alarms = true
  enable_cloudwatch_metrics    = true
  alarms_sns_topic_arn         = [dependency.sns.outputs.topic_arn]

  # Enable Capacity Providers for ECS Cluster Autoscaling. Refer to https://github.com/gruntwork-io/terraform-aws-service-catalog/blob/master/modules/services/ecs-cluster/core-concepts.md#how-do-you-configure-cluster-autoscaling for more information.
  capacity_provider_enabled  = true
  multi_az_capacity_provider = false
  capacity_provider_target   = 90
}