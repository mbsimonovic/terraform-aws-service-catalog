# ----------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS DEPLOY RUNNER WITH INVOCATION PERMISSION FOR GIVEN IAM ENTITIES
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "ecs_deploy_runner" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v1.0.8"
  source = "../../../../modules/mgmt/ecs-deploy-runner"

  name = var.name

  container_images = {
    deploy-runner = {
      docker_image = var.container_image.repo
      docker_tag   = var.container_image.tag
      secrets_manager_arns = {
        DEPLOY_SCRIPT_SSH_PRIVATE_KEY = var.ssh_private_key_secrets_manager_arn
      }
      default = true
    }
  }

  repository          = var.repository
  approved_apply_refs = var.approved_apply_refs

  iam_users  = var.iam_users
  iam_groups = var.iam_groups
  iam_roles  = var.iam_roles

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A VPC
# Provide a VPC with a NAT gateway in to which the ECS deploy runner will be created.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-mgmt?ref=v0.8.8"

  vpc_name         = "${var.name}-vpc"
  aws_region       = var.aws_region
  cidr_block       = "10.98.0.0/18"
  num_nat_gateways = 1
}
