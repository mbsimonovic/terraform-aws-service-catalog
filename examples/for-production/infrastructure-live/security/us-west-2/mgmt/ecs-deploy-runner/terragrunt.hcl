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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v0.36.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/mgmt/ecs-deploy-runner"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "vpc_mgmt" {
  config_path = "${get_terragrunt_dir()}/../vpc-mgmt"

  mock_outputs = {
    vpc_id             = "vpc-abcd1234"
    private_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
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

  # Extract the account_name for easy access
  account_name = local.account_vars.locals.account_name

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  # Read in data files containing IAM permissions for the deploy runner.
  read_only_permissions = yamldecode(
    templatefile(
      "${get_terragrunt_dir()}/read_only_permissions.yml",
      {
        state_bucket = local.region_vars.locals.state_bucket
      }
    )
  )
  deploy_permissions = yamldecode(
    templatefile(
      "${get_terragrunt_dir()}/deploy_permissions.yml",
      {
        state_bucket = local.region_vars.locals.state_bucket
      }
    )
  )

  state_bucket = local.region_vars.locals.state_bucket

  git_ssh_private_key_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:234567890123:secret:GitSSHPrivateKey"
  github_pat_secrets_manager_arn          = ""

}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name               = "ecs-deploy-runner"
  vpc_id             = dependency.vpc_mgmt.outputs.vpc_id
  private_subnet_ids = dependency.vpc_mgmt.outputs.private_subnet_ids



  # We don't need to build images in this account.
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
    allowed_apply_git_refs                 = ["main", ]
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

  container_cpu    = 4096
  container_memory = 16384
}
