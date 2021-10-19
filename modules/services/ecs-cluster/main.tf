# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS CLUSTER TO RUN DOCKER CONTAINERS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-ecs.git//modules/ecs-cluster?ref=v0.31.5"

  cluster_name     = var.cluster_name
  cluster_min_size = var.cluster_min_size
  cluster_max_size = var.cluster_max_size

  cluster_instance_ami              = module.ec2_baseline.existing_ami
  cluster_instance_type             = var.cluster_instance_type
  cluster_instance_keypair_name     = var.cluster_instance_keypair_name
  cluster_instance_user_data_base64 = module.ec2_baseline.cloud_init_rendered

  vpc_id                            = var.vpc_id
  vpc_subnet_ids                    = local.usable_subnet_ids
  tenancy                           = var.tenancy
  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids
  allow_ssh_from_cidr_blocks        = var.allow_ssh_from_cidr_blocks

  alb_security_group_ids = compact(concat(var.internal_alb_sg_ids, var.public_alb_sg_ids))

  capacity_provider_enabled        = var.capacity_provider_enabled
  multi_az_capacity_provider       = var.multi_az_capacity_provider
  capacity_provider_target         = var.capacity_provider_target
  capacity_provider_max_scale_step = var.capacity_provider_max_scale_step
  capacity_provider_min_scale_step = var.capacity_provider_min_scale_step

  autoscaling_termination_protection = var.autoscaling_termination_protection
}


# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE THE SUBNETS TO USE
# Some regions have restricted Availability Zones where not all instance types are available.
# Since the ecs-cluster module doesn't support multiple instance types, we need to allow filtering of availability zones.
# Which subnets are allowed is based on the disallowed availability zones input.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_subnet" "subnet_in_vpc" {
  for_each = { for id in var.vpc_subnet_ids : id => id }
  id       = each.key
}

locals {
  usable_subnet_ids = [
    for id, subnet in data.aws_subnet.subnet_in_vpc :
    id if contains(var.disallowed_availability_zones, subnet.availability_zone) == false
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "ecs-cluster-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  ip_lockdown_users = [var.default_user]
  # We want a space separated list of the users, quoted with ''
  ip_lockdown_users_bash_array = join(
    " ",
    [for user in local.ip_lockdown_users : "'${user}'"],
  )

  log_group = var.cloudwatch_log_group_name != "" ? var.cloudwatch_log_group_name : "${var.cluster_name}-logs"

  # Trim excess whitespace, because AWS will do that on deploy. This prevents
  # constant redeployment because the userdata hash doesn't match the trimmed
  # userdata hash.
  # See: https://github.com/hashicorp/terraform-provider-aws/issues/5011#issuecomment-878542063
  base_user_data = trimspace(templatefile(
    "${path.module}/user-data.sh",
    {
      cluster_name                        = var.cluster_name
      aws_region                          = data.aws_region.current.name
      enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
      enable_ssh_grunt                    = var.enable_ssh_grunt
      ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
      ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
      log_group_name                      = local.log_group
      external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
      enable_fail2ban                     = var.enable_fail2ban
      enable_ip_lockdown                  = var.enable_ip_lockdown
      ip_lockdown_users                   = local.ip_lockdown_users_bash_array
    },
  ))
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CLUSTER'S CPU, MEMORY, OR DISK SPACE USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster_cpu_memory_alarms" {
  create_resources = var.enable_ecs_cloudwatch_alarms

  source               = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ecs-cluster-alarms?ref=v0.30.2"
  ecs_cluster_name     = var.cluster_name
  alarm_sns_topic_arns = var.alarms_sns_topic_arn

  high_cpu_utilization_threshold          = var.high_cpu_utilization_threshold
  high_cpu_utilization_period             = var.high_cpu_utilization_period
  high_cpu_utilization_evaluation_periods = var.high_cpu_utilization_evaluation_periods
  high_cpu_utilization_statistic          = var.high_cpu_utilization_statistic

  high_memory_utilization_threshold          = var.high_memory_utilization_threshold
  high_memory_utilization_period             = var.high_memory_utilization_period
  high_memory_utilization_evaluation_periods = var.high_memory_utilization_evaluation_periods
  high_memory_utilization_statistic          = var.high_memory_utilization_statistic
}

module "metric_widget_ecs_cluster_cpu_usage" {

  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.cluster_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name],
  ]
}

module "metric_widget_ecs_cluster_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.cluster_name)} MemoryUtilization"

  metrics = [
    ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name],
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# BASE RESOURCES
# Includes resources common to all EC2 instances in the Service Catalog, including permissions for ssh-grunt, CloudWatch
# Logs aggregation, CloudWatch metrics, and CloudWatch alarms
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name                                = var.cluster_name
  enable_ssh_grunt                    = var.enable_ssh_grunt
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  iam_role_name                       = module.ecs_cluster.ecs_instance_iam_role_name
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.cluster_instance_ami
  ami_filters                         = var.cluster_instance_ami_filters

  # We use custom alarms for ECS, as specified above
  enable_instance_cloudwatch_alarms = false
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE ACCESS TO CERTAIN PORTS WITHIN THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "cluster_access" {
  count = length(var.enable_cluster_access_ports) * length(var.cluster_access_from_sgs)

  type                     = "ingress"
  from_port                = local.product[count.index][0]
  to_port                  = local.product[count.index][0]
  protocol                 = "tcp"
  source_security_group_id = local.product[count.index][1]
  security_group_id        = module.ecs_cluster.ecs_instance_security_group_id
}

locals {
  product = setproduct(var.enable_cluster_access_ports, var.cluster_access_from_sgs)
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT/REGION
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
