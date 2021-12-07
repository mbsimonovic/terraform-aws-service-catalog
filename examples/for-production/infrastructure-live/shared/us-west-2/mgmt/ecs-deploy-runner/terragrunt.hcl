# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/mgmt/ecs-deploy-runner.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  common_vars = include.envcommon.locals.common_vars
  aws_region  = include.envcommon.locals.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
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
      username_secrets_manager_arn = include.envcommon.locals.github_pat_secrets_manager_arn
      password_secrets_manager_arn = null
    }
    environment_vars = {}
    secrets_manager_env_vars = {
      GITHUB_OAUTH_TOKEN = include.envcommon.locals.github_pat_secrets_manager_arn
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
    repo_access_ssh_key_secrets_manager_arn = include.envcommon.locals.git_ssh_private_key_secrets_manager_arn
    repo_access_https_tokens = {
      github_token_secrets_manager_arn = include.envcommon.locals.github_pat_secrets_manager_arn
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
      GITHUB_OAUTH_TOKEN = include.envcommon.locals.github_pat_secrets_manager_arn
    }
  }
}