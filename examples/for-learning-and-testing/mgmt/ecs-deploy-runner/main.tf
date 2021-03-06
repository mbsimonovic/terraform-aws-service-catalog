# ----------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS DEPLOY RUNNER WITH INVOCATION PERMISSION FOR GIVEN IAM ENTITIES
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}

module "ecs_deploy_runner" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/ecs-deploy-runner?ref=v1.0.8"
  source = "../../../../modules/mgmt/ecs-deploy-runner"

  # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
  # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
  # regions that are enabled in your AWS account.
  providers = {
    aws                = aws.default
    aws.af_south_1     = aws.af_south_1
    aws.ap_east_1      = aws.ap_east_1
    aws.ap_northeast_1 = aws.ap_northeast_1
    aws.ap_northeast_2 = aws.ap_northeast_2
    aws.ap_northeast_3 = aws.ap_northeast_3
    aws.ap_south_1     = aws.ap_south_1
    aws.ap_southeast_1 = aws.ap_southeast_1
    aws.ap_southeast_2 = aws.ap_southeast_2
    aws.ap_southeast_3 = aws.ap_southeast_3
    aws.ca_central_1   = aws.ca_central_1
    aws.cn_north_1     = aws.cn_north_1
    aws.cn_northwest_1 = aws.cn_northwest_1
    aws.eu_central_1   = aws.eu_central_1
    aws.eu_north_1     = aws.eu_north_1
    aws.eu_south_1     = aws.eu_south_1
    aws.eu_west_1      = aws.eu_west_1
    aws.eu_west_2      = aws.eu_west_2
    aws.eu_west_3      = aws.eu_west_3
    aws.me_south_1     = aws.me_south_1
    aws.sa_east_1      = aws.sa_east_1
    aws.us_east_1      = aws.us_east_1
    aws.us_east_2      = aws.us_east_2
    aws.us_gov_east_1  = aws.us_gov_east_1
    aws.us_gov_west_1  = aws.us_gov_west_1
    aws.us_west_1      = aws.us_west_1
    aws.us_west_2      = aws.us_west_2
  }

  name = var.name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids

  shared_secrets_enabled     = true
  shared_secrets_kms_cmk_arn = aws_kms_key.shared_secret_grants.arn

  docker_image_builder_config = var.docker_image_builder_config
  ami_builder_config          = var.ami_builder_config
  terraform_planner_config    = var.terraform_planner_config
  terraform_applier_config    = var.terraform_applier_config

  invoke_schedule = var.invoke_schedule

  kms_grant_opt_in_regions = var.kms_grant_opt_in_regions

  ec2_worker_pool_configuration = (
    var.enable_ec2_worker_pool
    ? {
      # NOTE: these filters assume you created an AMI using the packer build script in the service module.
      ami_filters = {
        owners = ["self"]
        filters = [
          {
            name   = "tag:service"
            values = ["ecs-deploy-runner-worker"]
          },
          {
            name   = "tag:version"
            values = [var.ec2_worker_pool_ami_version_tag]
          },
        ]
      }
    }
    : null
  )

  iam_users  = var.iam_users
  iam_groups = var.iam_groups
  iam_roles  = var.iam_roles
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A KMS KEY FOR TESTING GRANTS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "shared_secret_grants" {
  deletion_window_in_days = 7

  provider = aws.default
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A VPC
# Provide a VPC with a NAT gateway in to which the ECS deploy runner will be created. Note that we can't use the default
# VPC because Fargate can only be deployed on private subnets.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "../../../../modules/networking/vpc"

  providers = {
    aws = aws.default
  }

  vpc_name         = "${var.name}-vpc"
  aws_region       = var.aws_region
  cidr_block       = "10.98.0.0/18"
  num_nat_gateways = 1
  create_flow_logs = false
}
