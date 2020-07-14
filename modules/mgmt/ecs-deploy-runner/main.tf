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
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ECS DEPLOY RUNNER IN THE STANDARD CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_deploy_runner" {
  # TODO: update to released version when app CI/CD feature is released
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner?ref=yori-app-cicd-feature"

  name             = var.name
  container_images = module.standard_config.container_images

  vpc_id         = var.vpc_id
  vpc_subnet_ids = var.private_subnet_ids
}

module "standard_config" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner-standard-configuration?ref=yori-app-cicd-feature"

  docker_image_builder = {
    container_image = var.docker_image_builder_config.container_image
    allowed_repos   = var.docker_image_builder_config.allowed_repos
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
  }

  ami_builder = {
    container_image                         = var.ami_builder_config.container_image
    allowed_repos                           = var.ami_builder_config.allowed_repos
    repo_access_ssh_key_secrets_manager_arn = var.ami_builder_config.repo_access_ssh_key_secrets_manager_arn
    secrets_manager_env_vars                = var.ami_builder_config.secrets_manager_env_vars
  }

  terraform_planner = {
    container_image                = var.terraform_planner_config.container_image
    infrastructure_live_repository = var.terraform_planner_config.infrastructure_live_repository
    secrets_manager_env_vars = merge(
      {
        DEPLOY_SCRIPT_SSH_PRIVATE_KEY = var.terraform_planner_config.repo_access_ssh_key_secrets_manager_arn
      },
      var.terraform_planner_config.secrets_manager_env_vars,
    )
  }

  terraform_applier = {
    container_image                         = var.terraform_applier_config.container_image
    infrastructure_live_repository          = var.terraform_applier_config.infrastructure_live_repository
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
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AWS PERMISSIONS TO ECS TASKS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  configure_docker_image_builder_iam_policy = var.docker_image_builder_config.iam_policy != null && length(var.docker_image_builder_config.iam_policy) > 0
  configure_ami_builder_iam_policy          = var.ami_builder_config.iam_policy != null && length(var.ami_builder_config.iam_policy) > 0
  configure_terraform_planner_iam_policy    = var.terraform_planner_config.iam_policy != null && length(var.terraform_planner_config.iam_policy) > 0
  configure_terraform_applier_iam_policy    = var.terraform_applier_config.iam_policy != null && length(var.terraform_applier_config.iam_policy) > 0
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
# CREATE IAM POLICY WITH PERMISSIONS TO INVOKE THE ECS DEPLOY RUNNER ATTACH TO IAM ENTITIES
# ---------------------------------------------------------------------------------------------------------------------

module "invoke_policy" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner-invoke-iam-policy?ref=master"

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
