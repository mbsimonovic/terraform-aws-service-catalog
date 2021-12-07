
# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for mgmt/ecs-deploy-runner. The common variables for each environment to
# deploy mgmt/ecs-deploy-runner are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v0.66.1"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/mgmt/ecs-deploy-runner"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc_mgmt" {
  config_path = "${get_terragrunt_dir()}/../networking/vpc"

  mock_outputs = {
    vpc_id             = "vpc-abcd1234"
    private_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Generators are used to generate additional Terraform code that is necessary to deploy a module.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE A PROVIDER FOR EACH AWS REGION
# To deploy a multi-region module, we have to configure a provider with a unique alias for each of the regions AWS
# supports and pass all these providers to the multi-region module in a provider = { ... } block. You MUST create a
# provider block for EVERY one of these AWS regions, but you should specify the ones to use and authenticate to (the
# ones actually enabled in your AWS account) using opt_in_regions.
# ---------------------------------------------------------------------------------------------------------------------

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<EOF
%{for region in local.all_aws_regions}
provider "aws" {
  region = "${region}"
  alias  = "${replace(region, "-", "_")}"
  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = ${contains(coalesce(local.opt_in_regions, []), region) ? "false" : "true"}
  skip_requesting_account_id  = ${contains(coalesce(local.opt_in_regions, []), region) ? "false" : "true"}
}
%{endfor}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner"

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

  # Read in data files containing IAM permissions for the deploy runner.
  read_only_permissions = yamldecode(
    templatefile(
      "${get_parent_terragrunt_dir()}/read_only_permissions.yml",
      {
        state_bucket = local.region_vars.locals.state_bucket
      }
    )
  )
  deploy_permissions = yamldecode(
    templatefile(
      "${get_parent_terragrunt_dir()}/deploy_permissions.yml",
      {
        state_bucket = local.region_vars.locals.state_bucket
      }
    )
  )

  state_bucket = local.region_vars.locals.state_bucket

  git_ssh_private_key_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:234567890123:secret:GitSSHPrivateKey"
  github_pat_secrets_manager_arn          = ""

  # The following locals are used for constructing multi region provider configurations for the underlying module.
  multi_region_vars = read_terragrunt_config(find_in_parent_folders("multi_region_common.hcl"))
  all_aws_regions   = local.multi_region_vars.locals.all_aws_regions
  opt_in_regions    = local.multi_region_vars.locals.opt_in_regions
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name               = "ecs-deploy-runner"
  vpc_id             = dependency.vpc_mgmt.outputs.vpc_id
  private_subnet_ids = dependency.vpc_mgmt.outputs.private_subnet_ids

  shared_secrets_enabled     = true
  shared_secrets_kms_cmk_arn = "arn:aws:kms:us-east-1:234567890123:alias/shared-secrets"

  # Set the image builders to null by default, as only the shared account needs the image builders.
  docker_image_builder_config = null
  ami_builder_config          = null

  terraform_planner_config = {
    container_image = {
      docker_image = local.common_vars.locals.deploy_runner_ecr_uri
      docker_tag   = local.common_vars.locals.deploy_runner_container_image_tag
    }
    infrastructure_live_repositories = concat(
      [local.common_vars.locals.infra_live_repo_ssh],
      local.common_vars.locals.additional_plan_and_apply_repos,
    )
    infrastructure_live_repositories_regex  = []
    repo_access_ssh_key_secrets_manager_arn = local.git_ssh_private_key_secrets_manager_arn
    repo_access_https_tokens = {
      github_token_secrets_manager_arn = local.github_pat_secrets_manager_arn
    }
    secrets_manager_env_vars = {
      GITHUB_OAUTH_TOKEN = local.github_pat_secrets_manager_arn
    }
    environment_vars = {}
    iam_policy       = local.read_only_permissions
  }

  terraform_applier_config = {
    container_image = {
      docker_image = local.common_vars.locals.deploy_runner_ecr_uri
      docker_tag   = local.common_vars.locals.deploy_runner_container_image_tag
    }
    infrastructure_live_repositories = concat(
      [local.common_vars.locals.infra_live_repo_ssh],
      local.common_vars.locals.additional_plan_and_apply_repos,
    )
    infrastructure_live_repositories_regex = []
    allowed_update_variable_names          = ["tag", "ami", "docker_tag", "ami_version_tag", ]
    allowed_apply_git_refs                 = ["main", "origin/main", ]
    machine_user_git_info = {
      name  = "gruntbot"
      email = "gruntbot@gruntwork.io"
    }
    repo_access_ssh_key_secrets_manager_arn = local.git_ssh_private_key_secrets_manager_arn
    repo_access_https_tokens = {
      github_token_secrets_manager_arn = local.github_pat_secrets_manager_arn
    }
    secrets_manager_env_vars = {
      GITHUB_OAUTH_TOKEN = local.github_pat_secrets_manager_arn
    }
    environment_vars = {}
    iam_policy       = local.deploy_permissions
  }

  # A list of role names that should be given permissions to invoke the infrastructure CI/CD pipeline.
  iam_roles = ["allow-auto-deploy-from-other-accounts", ]

  container_cpu        = 2048
  container_memory     = 4096
  container_max_cpu    = 8192
  container_max_memory = 32768

  # Configure opt in regions for each multi region service based on locally configured setting.
  kms_grant_opt_in_regions = local.opt_in_regions

  # The following configuration provisions EC2 instances to use with the ECS deploy runner. Fargate workers are pay per
  # use and generally preferable, but they are limited to minimal resources in new accounts (2vCPUs, 4GB RAM). When
  # deploying many infrastructure resources at once this may not be enough for terragrunt to be able to deploy
  # everything. We recommend using EC2 based workers for the initial deployment and setup, and once you have launched,
  # to spin down the EC2 workers by removing the following input to replace them with purely Fargate workers.
  ec2_worker_pool_configuration = {
    ami_filters = {
      owners = [local.common_vars.locals.account_ids.shared]
      filters = [
        {
          name   = "name"
          values = ["ecs-deploy-runner-worker-v0.66.1-*"]
        },
      ]
    }
    instance_type = "m5.2xlarge"
  }
}
