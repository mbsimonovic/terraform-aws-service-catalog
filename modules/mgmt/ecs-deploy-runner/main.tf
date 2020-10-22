# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH THE STANDARD ECS DEPLOY RUNNER
# The ECS deploy runner is a ECS Fargate cluster that can be used to run infrastructure code remotely in your AWS
# accounts as part of CI/CD workflows. The standard version of the ECS deploy runner is set up to support canonical
# infrastructure deployment workflows for:
# - Building a docker image and deploying the new image using terraform/terragrunt
# - Building an AMI and deploying the new image using terraform/terragrunt
# - Deploying arbitrary infrastructure using terraform/terragrunt
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that may have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ECS DEPLOY RUNNER IN THE STANDARD CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_deploy_runner" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner?ref=v0.29.0"

  name                          = var.name
  container_images              = module.standard_config.container_images
  ec2_worker_pool_configuration = local.ec2_worker_pool_configuration
  container_default_launch_type = var.container_default_launch_type

  vpc_id         = var.vpc_id
  vpc_subnet_ids = var.private_subnet_ids

  container_cpu        = var.container_cpu
  container_memory     = var.container_memory
  container_max_cpu    = var.container_max_cpu
  container_max_memory = var.container_max_memory
}

module "standard_config" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner-standard-configuration?ref=v0.29.0"

  docker_image_builder = (
    var.docker_image_builder_config != null
    ? {
      container_image     = var.docker_image_builder_config.container_image
      allowed_repos       = var.docker_image_builder_config.allowed_repos
      allowed_repos_regex = var.docker_image_builder_config.allowed_repos_regex
      secrets_manager_env_vars = merge(
        (
          var.docker_image_builder_config.git_config != null && var.docker_image_builder_config.git_config.username_secrets_manager_arn != null
          ? {
            GIT_USERNAME = var.docker_image_builder_config.git_config.username_secrets_manager_arn
          }
          : {}
        ),
        (
          var.docker_image_builder_config.git_config != null && var.docker_image_builder_config.git_config.password_secrets_manager_arn != null
          ? {
            GIT_PASSWORD = var.docker_image_builder_config.git_config.password_secrets_manager_arn
          }
          : {}
        ),
        var.docker_image_builder_config.secrets_manager_env_vars,
      )
      environment_vars = var.docker_image_builder_config.environment_vars
    }
    : null
  )

  ami_builder = (
    var.ami_builder_config != null
    ? {
      container_image                         = var.ami_builder_config.container_image
      allowed_repos                           = var.ami_builder_config.allowed_repos
      allowed_repos_regex                     = var.ami_builder_config.allowed_repos_regex
      repo_access_ssh_key_secrets_manager_arn = var.ami_builder_config.repo_access_ssh_key_secrets_manager_arn
      secrets_manager_env_vars                = var.ami_builder_config.secrets_manager_env_vars
      environment_vars                        = var.ami_builder_config.environment_vars
    }
    : null
  )

  terraform_planner = (
    var.terraform_planner_config != null
    ? {
      container_image                        = var.terraform_planner_config.container_image
      infrastructure_live_repositories       = var.terraform_planner_config.infrastructure_live_repositories
      infrastructure_live_repositories_regex = var.terraform_planner_config.infrastructure_live_repositories_regex
      secrets_manager_env_vars = merge(
        {
          DEPLOY_SCRIPT_SSH_PRIVATE_KEY = var.terraform_planner_config.repo_access_ssh_key_secrets_manager_arn
        },
        var.terraform_planner_config.secrets_manager_env_vars,
      )
      environment_vars = var.terraform_planner_config.environment_vars
    }
    : null
  )

  terraform_applier = (
    var.terraform_applier_config != null
    ? {
      container_image                         = var.terraform_applier_config.container_image
      infrastructure_live_repositories        = var.terraform_applier_config.infrastructure_live_repositories
      infrastructure_live_repositories_regex  = var.terraform_applier_config.infrastructure_live_repositories_regex
      allowed_apply_git_refs                  = var.terraform_applier_config.allowed_apply_git_refs
      machine_user_git_info                   = var.terraform_applier_config.machine_user_git_info
      allowed_update_variable_names           = var.terraform_applier_config.allowed_update_variable_names
      repo_access_ssh_key_secrets_manager_arn = var.terraform_applier_config.repo_access_ssh_key_secrets_manager_arn
      secrets_manager_env_vars = merge(
        {
          DEPLOY_SCRIPT_SSH_PRIVATE_KEY = var.terraform_applier_config.repo_access_ssh_key_secrets_manager_arn
        },
        var.terraform_applier_config.secrets_manager_env_vars,
      )
      environment_vars = var.terraform_applier_config.environment_vars
    }
    : null
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 WORKER POOL SETTINGS
# Configure the baseline IAM permissions for the various services, as well as the user data boot script.
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name          = var.name
  iam_role_name = module.ecs_deploy_runner.ecs_ec2_worker_iam_role.name

  enable_cloudwatch_log_aggregation = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "enable_cloudwatch_log_aggregation", true)
    : false
  )
  enable_cloudwatch_metrics = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "enable_cloudwatch_metrics", true)
    : false
  )
  enable_asg_cloudwatch_alarms = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "enable_asg_cloudwatch_alarms", true)
    : false
  )
  asg_names = [module.ecs_deploy_runner.ecs_ec2_worker_asg_name]
  alarms_sns_topic_arn = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "alarms_sns_topic_arn", null)
    : null
  )
  should_render_cloud_init = local.should_use_ec2_worker_pool
  cloud_init_parts         = local.cloud_init_parts
  ami = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "ami", null)
    : null
  )
  ami_filters = (
    local.should_use_ec2_worker_pool
    ? lookup(var.ec2_worker_pool_configuration, "ami_filters", null)
    : null
  )

  # Disable ssh grunt, given the implications of such access to the CI/CD pipeline.
  enable_ssh_grunt                    = false
  external_account_ssh_grunt_role_arn = ""
}

locals {
  should_use_ec2_worker_pool = var.ec2_worker_pool_configuration != null
  ec2_worker_pool_configuration = (
    local.should_use_ec2_worker_pool
    ? {
      min_size         = lookup(var.ec2_worker_pool_configuration, "min_size", 1)
      max_size         = lookup(var.ec2_worker_pool_configuration, "max_size", 2)
      instance_type    = lookup(var.ec2_worker_pool_configuration, "instance_type", "m5.large")
      ami              = module.ec2_baseline.existing_ami
      user_data_base64 = module.ec2_baseline.cloud_init_rendered
      user_data        = null
    }
    : null
  )

  ip_lockdown_users = (
    local.should_use_ec2_worker_pool
    ? compact([
      lookup(var.ec2_worker_pool_configuration, "default_user", "ec2-user"),
      # User used to push cloudwatch metrics from the server. This should only be included in the ip-lockdown list if
      # reporting cloudwatch metrics is enabled.
      lookup(var.ec2_worker_pool_configuration, "enable_cloudwatch_metrics", true) ? "cwmonitoring" : ""
    ])
    : null
  )
  # We want a space separated list of the users, quoted with ''
  ip_lockdown_users_bash_array = (
    local.should_use_ec2_worker_pool
    ? join(
      " ",
      [for user in local.ip_lockdown_users : "'${user}'"],
    )
    : null
  )

  # Default cloud init script for this module
  cloud_init = (
    local.should_use_ec2_worker_pool
    ? {
      filename     = "ecs-deploy-runner-default-cloud-init"
      content_type = "text/x-shellscript"
      content = templatefile(
        "${path.module}/user-data.sh",
        {
          log_group_name                    = var.name
          enable_cloudwatch_log_aggregation = lookup(var.ec2_worker_pool_configuration, "enable_cloudwatch_log_aggregation", true)
          enable_fail2ban                   = lookup(var.ec2_worker_pool_configuration, "enable_fail2ban", true)
          enable_ip_lockdown                = lookup(var.ec2_worker_pool_configuration, "enable_ip_lockdown", true)
          ecs_cluster_name                  = var.name
          aws_region                        = data.aws_region.current.name
          ip_lockdown_users                 = local.ip_lockdown_users_bash_array
        },
      )
    }
    : null
  )

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = (
    local.should_use_ec2_worker_pool
    ? merge(
      { default : local.cloud_init },
      lookup(var.ec2_worker_pool_configuration, "cloud_init_parts", {}),
    )
    : {}
  )
}


# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AWS PERMISSIONS TO ECS TASKS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  configure_docker_image_builder_iam_policy = var.docker_image_builder_config != null ? length(var.docker_image_builder_config.iam_policy) > 0 : false
  configure_ami_builder_iam_policy          = var.ami_builder_config != null ? length(var.ami_builder_config.iam_policy) > 0 : false
  configure_terraform_planner_iam_policy    = var.terraform_planner_config != null ? length(var.terraform_planner_config.iam_policy) > 0 : false
  configure_terraform_applier_iam_policy    = var.terraform_applier_config != null ? length(var.terraform_applier_config.iam_policy) > 0 : false
}

resource "aws_iam_role_policy" "docker_image_builder" {
  count  = local.configure_docker_image_builder_iam_policy ? 1 : 0
  name   = "access-to-services"
  role   = module.ecs_deploy_runner.ecs_task_iam_roles["docker-image-builder"].name
  policy = data.aws_iam_policy_document.docker_image_builder[0].json
}

data "aws_iam_policy_document" "docker_image_builder" {
  count = local.configure_docker_image_builder_iam_policy ? 1 : 0
  dynamic "statement" {
    for_each = var.docker_image_builder_config.iam_policy
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "ami_builder" {
  count  = local.configure_ami_builder_iam_policy ? 1 : 0
  name   = "access-to-services"
  role   = module.ecs_deploy_runner.ecs_task_iam_roles["ami-builder"].name
  policy = data.aws_iam_policy_document.ami_builder[0].json
}

data "aws_iam_policy_document" "ami_builder" {
  count = local.configure_ami_builder_iam_policy ? 1 : 0
  dynamic "statement" {
    for_each = var.ami_builder_config.iam_policy
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "terraform_planner" {
  count  = local.configure_terraform_planner_iam_policy ? 1 : 0
  name   = "access-to-services"
  role   = module.ecs_deploy_runner.ecs_task_iam_roles["terraform-planner"].name
  policy = data.aws_iam_policy_document.terraform_planner[0].json
}

data "aws_iam_policy_document" "terraform_planner" {
  count = local.configure_terraform_planner_iam_policy ? 1 : 0
  dynamic "statement" {
    for_each = var.terraform_planner_config.iam_policy
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "terraform_applier" {
  count  = local.configure_terraform_applier_iam_policy ? 1 : 0
  name   = "access-to-services"
  role   = module.ecs_deploy_runner.ecs_task_iam_roles["terraform-applier"].name
  policy = data.aws_iam_policy_document.terraform_applier[0].json
}

data "aws_iam_policy_document" "terraform_applier" {
  count = local.configure_terraform_applier_iam_policy ? 1 : 0
  dynamic "statement" {
    for_each = var.terraform_applier_config.iam_policy
    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE KMS GRANTS TO ALLOW RESPECTIVE CONTAINERS FOR SNAPSHOTS
# Creates the following grants to ami-builder and terraform-applier for each snapshot encryption key:
# - Encrypt
# - Decrypt
# - ReEncryptFrom
# - ReEncryptTo
# - GenerateDataKey
# - GenerateDataKeyWithoutPlaintext
# - DescribeKey
# - CreateGrant
#
# See https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html for more
# details.
# ---------------------------------------------------------------------------------------------------------------------

module "kms_grants" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-grant-multi-region?ref=v0.39.2"

  aws_account_id    = data.aws_caller_identity.current.account_id
  kms_grant_regions = local.kms_grant_regions
  kms_grants        = local.kms_grants
}

locals {
  key_use_actions = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant",
  ]

  # This regex can be used to extract the region from an ARN string. It works by parsing the first 4 parts of the arn,
  # matching words that don't have : in them, and assigning a group to the 4th part (the region).
  extract_region_regex = "arn:[^:]*:[^:]*:([^:]+):.+"

  ami_builder_kms_grant_regions = (
    var.ami_builder_config != null
    ? {
      for name, cmk_arn in var.snapshot_encryption_kms_cmk_arns :
      "ami-builder-${name}" => regex(local.extract_region_regex, cmk_arn)[0]
    }
    : {}
  )
  ami_builder_kms_grants = (
    var.ami_builder_config != null
    ? {
      for name, cmk_arn in var.snapshot_encryption_kms_cmk_arns :
      "ami-builder-${name}" => {
        kms_cmk_arn        = cmk_arn
        grantee_principal  = module.ecs_deploy_runner.ecs_task_iam_roles["ami-builder"].arn
        granted_operations = local.key_use_actions
      }
    }
    : {}
  )

  terraform_applier_kms_grant_regions = (
    var.terraform_applier_config != null
    ? {
      for name, cmk_arn in var.snapshot_encryption_kms_cmk_arns :
      "terraform-applier-${name}" => regex(local.extract_region_regex, cmk_arn)[0]
    }
    : {}
  )
  terraform_applier_kms_grants = (
    var.terraform_applier_config != null
    ? {
      for name, cmk_arn in var.snapshot_encryption_kms_cmk_arns :
      "terraform-applier-${name}" => {
        kms_cmk_arn        = cmk_arn
        grantee_principal  = module.ecs_deploy_runner.ecs_task_iam_roles["terraform-applier"].arn
        granted_operations = local.key_use_actions
      }
    }
    : {}
  )

  kms_grant_regions = merge(local.ami_builder_kms_grant_regions, local.terraform_applier_kms_grant_regions)
  kms_grants        = merge(local.ami_builder_kms_grants, local.terraform_applier_kms_grants)
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM POLICY WITH PERMISSIONS TO INVOKE THE ECS DEPLOY RUNNER ATTACH TO IAM ENTITIES
# ---------------------------------------------------------------------------------------------------------------------

module "invoke_policy" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner-invoke-iam-policy?ref=v0.29.0"

  name                                      = "invoke-${var.name}"
  deploy_runner_invoker_lambda_function_arn = module.ecs_deploy_runner.invoker_function_arn
  deploy_runner_ecs_cluster_arn             = module.ecs_deploy_runner.ecs_cluster_arn
  deploy_runner_cloudwatch_log_group_name   = module.ecs_deploy_runner.cloudwatch_log_group_name
}

resource "aws_iam_role_policy_attachment" "attach_invoke_to_roles" {
  for_each   = length(var.iam_roles) > 0 ? { for k in var.iam_roles : k => k } : {}
  role       = each.key
  policy_arn = module.invoke_policy.arn
}

resource "aws_iam_user_policy_attachment" "attach_invoke_to_users" {
  for_each   = length(var.iam_users) > 0 ? { for k in var.iam_users : k => k } : {}
  user       = each.key
  policy_arn = module.invoke_policy.arn
}

resource "aws_iam_group_policy_attachment" "attach_invoke_to_groups" {
  for_each   = length(var.iam_groups) > 0 ? { for k in var.iam_groups : k => k } : {}
  group      = each.key
  policy_arn = module.invoke_policy.arn
}


# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
