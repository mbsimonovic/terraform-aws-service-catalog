# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for services/eks-cluster. The common variables for each environment to
# deploy services/eks-cluster are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-cluster?ref=v0.82.0"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/services/eks-cluster"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                 = "vpc-efgh5678"
    private_app_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "baseline" {
  config_path = "${get_terragrunt_dir()}/../../../../_global/account-baseline"

  mock_outputs = {
    allow_full_access_from_other_accounts_iam_role_arn = "arn:aws:iam:us-east-1:123456789012:full-access-NZJ5JSMVGFIE"
    allow_dev_access_from_other_accounts_iam_role_arn  = "arn:aws:iam:us-east-1:123456789012:dev-access-NZJ5JSMVGFIE"
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

dependency "ecs_deploy_runner" {
  config_path = "${get_terragrunt_dir()}/../../../mgmt/ecs-deploy-runner"

  mock_outputs = {
    ecs_task_iam_roles = {
      "terraform-applier" = {
        "arn" = "arn:aws:iam::12345679012:role/role-mock-2",
      "name" = "ecs-task-iam-role-mock-2", },
      "terraform-planner" = {
        "arn" = "arn:aws:iam::12345679012:role/role-mock-1",
      "name" = "ecs-task-iam-role-mock-1", },
    }

    security_group_allow_all_outbound_id = "sg-mockmockmockmock0"
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

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-cluster"

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
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  cluster_name = "${local.name_prefix}-${local.account_name}"

  # We deploy EKS into the app VPC, inside the private app tier.
  vpc_id                                     = dependency.vpc.outputs.vpc_id
  schedule_control_plane_services_on_fargate = true
  control_plane_vpc_subnet_ids               = dependency.vpc.outputs.private_app_subnet_ids
  worker_vpc_subnet_ids                      = dependency.vpc.outputs.private_app_subnet_ids

  # Configure worker node settings. This configuration uses Managed Node Groups as the worker pool.
  cluster_instance_ami = ""
  cluster_instance_ami_filters = {
    owners = [local.common_vars.locals.account_ids.shared]
    filters = [
      {
        name   = "name"
        values = ["eks-workers-v0.82.0-*"]
      },
    ]
  }
  cluster_instance_keypair_name       = "eks-cluster-admin-v1"
  external_account_ssh_grunt_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids.security}:role/allow-ssh-grunt-access-from-other-accounts"
  managed_node_group_configurations = {
    group = {
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.micro"]
      subnet_ids     = dependency.vpc.outputs.private_app_subnet_ids
    }
  }

  allow_inbound_api_access_from_security_groups = [dependency.ecs_deploy_runner.outputs.security_group_allow_all_outbound_id]
  allow_private_api_access_from_security_groups = [dependency.network_bastion.outputs.security_group_id]
  allow_inbound_ssh_from_security_groups        = [dependency.network_bastion.outputs.security_group_id]

  iam_role_to_rbac_group_mapping = {
    "arn:aws:iam::${local.common_vars.locals.account_ids[local.account_name]}:role/GruntworkAccountAccessRole" = ["system:masters"]
    (dependency.baseline.outputs.allow_full_access_from_other_accounts_iam_role_arn)                           = ["system:masters"]
    (dependency.baseline.outputs.allow_dev_access_from_other_accounts_iam_role_arn)                            = ["system:masters"]
    (dependency.ecs_deploy_runner.outputs.ecs_task_iam_roles["terraform-planner"]["arn"])                      = ["system:masters"]
    (dependency.ecs_deploy_runner.outputs.ecs_task_iam_roles["terraform-applier"]["arn"])                      = ["system:masters"]
  }

  endpoint_public_access                    = true
  allow_inbound_api_access_from_cidr_blocks = ["0.0.0.0/0"]

  alarms_sns_topic_arn = [dependency.sns.outputs.topic_arn]
}