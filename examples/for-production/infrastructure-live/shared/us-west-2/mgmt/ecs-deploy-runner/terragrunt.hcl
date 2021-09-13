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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v0.60.1"
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

  # The following locals are used for constructing multi region provider configurations for the underlying module.

  # A list of all AWS regions
  all_aws_regions = [
    "af-south-1",
    "ap-east-1",
    "ap-northeast-1",
    "ap-northeast-2",
    "ap-northeast-3",
    "ap-south-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ca-central-1",
    "cn-north-1",
    "cn-northwest-1",
    "eu-central-1",
    "eu-north-1",
    "eu-south-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "me-south-1",
    "sa-east-1",
    "us-east-1",
    "us-east-2",
    "us-gov-east-1",
    "us-gov-west-1",
    "us-west-1",
    "us-west-2",
  ]

  # Creates resources in the specified regions. The best practice is to enable multiregion modules in all enabled
  # regions in your AWS account. To get the list of regions enabled in your AWS account, you can use the AWS CLI: aws
  # ec2 describe-regions.
  opt_in_regions = [
    "eu-north-1",
    "ap-south-1",
    "eu-west-3",
    "eu-west-2",
    "eu-west-1",
    "ap-northeast-2",
    "ap-northeast-1",
    "sa-east-1",
    "ca-central-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "eu-central-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",

    # By default, skip regions that are not enabled in most AWS accounts:
    #
    #  "af-south-1",     # Cape Town
    #  "ap-east-1",      # Hong Kong
    #  "eu-south-1",     # Milan
    #  "me-south-1",     # Bahrain
    #  "us-gov-east-1",  # GovCloud
    #  "us-gov-west-1",  # GovCloud
    #  "cn-north-1",     # China
    #  "cn-northwest-1", # China
    #
    # This region is enabled by default but is brand-new and some services like AWS Config don't work.
    # "ap-northeast-3", # Asia Pacific (Osaka)
  ]

}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name               = "ecs-deploy-runner"
  vpc_id             = dependency.vpc_mgmt.outputs.vpc_id
  private_subnet_ids = dependency.vpc_mgmt.outputs.private_subnet_ids

  shared_secrets_enabled     = true
  shared_secrets_kms_cmk_arn = "arn:aws:kms:us-east-1:234567890123:alias/shared-secrets"

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
      owners = [local.common_vars.locals.accounts.shared]
      filters = [
        {
          name   = "name"
          values = ["ecs-deploy-runner-worker-v0.60.1-*"]
        },
      ]
    }
    instance_type = "m5.2xlarge"
  }
}
