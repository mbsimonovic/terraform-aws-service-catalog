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

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids

  docker_image_builder_config = var.docker_image_builder_config
  ami_builder_config          = var.ami_builder_config
  terraform_planner_config    = var.terraform_planner_config
  terraform_applier_config    = var.terraform_applier_config

  iam_users  = var.iam_users
  iam_groups = var.iam_groups
  iam_roles  = var.iam_roles
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A VPC
# Provide a VPC with a NAT gateway in to which the ECS deploy runner will be created. Note that we can't use the default
# VPC because Fargate can only be deployed on private subnets.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "../../../../modules/networking/vpc"

  vpc_name         = "${var.name}-vpc"
  aws_region       = var.aws_region
  cidr_block       = "10.98.0.0/18"
  num_nat_gateways = 1
  create_flow_logs = false
}
