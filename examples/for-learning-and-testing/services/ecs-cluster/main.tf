# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ECS CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "ecs_cluster" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/ecs-cluster?ref=1.0.8"
  source = "../../../../modules/services/ecs-cluster"

  cluster_name          = var.cluster_name
  cluster_instance_type = "t3.small"
  cluster_instance_ami  = null
  cluster_instance_ami_filters = {
    owners = ["self"]
    filters = [
      {
        name   = "tag:service"
        values = ["ecs-cluster-instance"]
      },
      {
        name   = "tag:version"
        values = [var.cluster_instance_ami_version_tag]
      },
    ]
  }

  cluster_max_size = var.cluster_max_size
  cluster_min_size = var.cluster_min_size

  enable_ecs_cloudwatch_alarms = var.enable_ecs_cloudwatch_alarms

  # For this simple example, use a regular keypair instead of ssh-grunt
  cluster_instance_keypair_name = var.cluster_instance_keypair_name
  enable_ssh_grunt              = false

  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = tolist(data.aws_subnet_ids.default.ids)

  # cloud-init / user-data variables
  enable_cloudwatch_log_aggregation = var.enable_cloudwatch_log_aggregation

  enable_fail2ban    = var.enable_fail2ban
  enable_ip_lockdown = var.enable_ip_lockdown

}

# Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

# Look up the default VPC's subnets
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
