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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v0.38.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/mgmt/ecs-deploy-runner"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}


dependency "account_baseline" {
  config_path = "${get_terragrunt_dir()}/../../../_global/account-baseline"
  mock_outputs = {
    kms_key_arns = {
      (local.aws_region) = {
        "ami-encryption" = "arn:aws:kms:us-east-1:111111111111:key/example-key-1111"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
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



  docker_image_builder_config = {
    container_image = {
      docker_image = local.common_vars.locals.kaniko_ecr_uri
      docker_tag   = local.common_vars.locals.kaniko_container_image_tag
    }
    iam_policy = {
      ECRAccess = {
        effect    = "Allow"
        actions   = ["ecr:*"]
        resources = ["*"]
      }
    }

    allowed_repos = [
      local.common_vars.locals.infra_live_repo_https,
      "https://github.com/gruntwork-io/terraform-aws-ci.git",
    ]
    allowed_repos_regex = []
    git_config = {
      # For GitHub access, we only need to set username to PAT.
      username_secrets_manager_arn = local.github_pat_secrets_manager_arn
      password_secrets_manager_arn = null
    }
    environment_vars = {}
    secrets_manager_env_vars = {
      GITHUB_OAUTH_TOKEN = local.github_pat_secrets_manager_arn
    }
  }

  ami_builder_config = {
    container_image = {
      docker_image = local.common_vars.locals.deploy_runner_ecr_uri
      docker_tag   = local.common_vars.locals.deploy_runner_container_image_tag
    }
    allowed_repos = [
      local.common_vars.locals.infra_live_repo_ssh,
      # Also allow building from Gruntwork Service Catalog repo
      "https://github.com/gruntwork-io/terraform-aws-service-catalog.git",
      # Also allow building from Gruntwork Sample App repo
      "https://github.com/gruntwork-io/aws-sample-app.git",
    ]
    allowed_repos_regex                     = []
    repo_access_ssh_key_secrets_manager_arn = local.git_ssh_private_key_secrets_manager_arn
    repo_access_https_tokens = {
      github_token_secrets_manager_arn = local.github_pat_secrets_manager_arn
    }
    iam_policy = {
      EC2ServiceDeployAccess = {
        effect    = "Allow"
        actions   = ["ec2:*"]
        resources = ["*"]
      }
      SharedAMIEncryptionKeyAccess = {
        effect = "Allow"
        actions = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:RevokeGrant"
        ]
        resources = [
          # The hard-coded value here must match the alias passed in the kms_customer_master_keys input in account-baseline-app
          dependency.account_baseline.outputs.kms_key_arns[local.aws_region]["ami-encryption"],
        ]
      }
    }
    environment_vars = {}
    secrets_manager_env_vars = {
      GITHUB_OAUTH_TOKEN = local.github_pat_secrets_manager_arn
    }
  }

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
