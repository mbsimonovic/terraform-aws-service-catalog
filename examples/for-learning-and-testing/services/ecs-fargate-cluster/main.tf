# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ECS CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "ecs_cluster" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/ecs-fargate-cluster?ref=1.0.8"
  source = "../../../../modules/services/ecs-fargate-cluster"

  cluster_name = var.cluster_name
}
