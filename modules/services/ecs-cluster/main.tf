# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS CLUSTER TO RUN DOCKER CONTAINERS
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
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-cluster?ref=v0.23.0"

  cluster_name     = var.cluster_name
  cluster_min_size = var.cluster_min_size
  cluster_max_size = var.cluster_max_size

  cluster_instance_ami              = module.ec2_baseline.existing_ami
  cluster_instance_type             = var.cluster_instance_type
  cluster_instance_keypair_name     = var.cluster_instance_keypair_name
  cluster_instance_user_data_base64 = module.ec2_baseline.cloud_init_rendered

  vpc_id                            = var.vpc_id
  vpc_subnet_ids                    = var.vpc_subnet_ids
  tenancy                           = var.tenancy
  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids

  alb_security_group_ids = compact(concat(var.internal_alb_sg_ids, var.public_alb_sg_ids))

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
    content      = data.template_file.user_data.rendered
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    cluster_name                        = var.cluster_name
    aws_region                          = data.aws_region.current.name
    enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
    enable_ssh_grunt                    = var.enable_ssh_grunt
    ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
    ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
    log_group_name                      = "${var.cluster_name}-logs"
    external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
    enable_fail2ban                     = var.enable_fail2ban
    enable_ip_lockdown                  = var.enable_ip_lockdown
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source      = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.22.2"
  name_prefix = var.cluster_name

  # We set this to false so that the cloudwatch-custom-metrics-iam policy generates JSON for the policy, but does not
  # create a standalone IAM policy with that JSON. We'll instead add that JSON to the ECS cluster IAM role.
  create_resources = false
}

resource "aws_iam_role_policy" "custom_cloudwatch_logging" {
  count  = var.enable_cloudwatch_log_aggregation ? 1 : 0
  name   = "cloudwatch-log-aggregation"
  role   = module.ecs_cluster.ecs_instance_iam_role_id
  policy = module.ec2_baseline.cloudwatch_logs_permissions_json
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CLUSTER'S CPU, MEMORY, OR DISK SPACE USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster_cpu_memory_alarms" {
  create_resources = var.enable_ecs_cloudwatch_alarms

  source               = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ecs-cluster-alarms?ref=v0.22.2"
  ecs_cluster_name     = var.cluster_name
  alarm_sns_topic_arns = var.alarms_sns_topic_arn

  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "metric_widget_ecs_cluster_cpu_usage" {

  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.22.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.cluster_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name],
  ]
}

module "metric_widget_ecs_cluster_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.22.2"

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
  # We use custom metrics for ECS, as specified above
  enable_cloudwatch_metrics = false
  iam_role_name             = module.ecs_cluster.ecs_instance_iam_role_name
  cloud_init_parts          = local.cloud_init_parts
  ami                       = var.cluster_instance_ami
  ami_filters               = var.cluster_instance_ami_filters
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD AN AUTO SCALING POLICY TO ADD MORE INSTANCES WHEN CPU USAGE IS HIGH
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                      = "${var.cluster_name}-scale-out"
  autoscaling_group_name    = module.ecs_cluster.ecs_cluster_asg_name
  adjustment_type           = "ChangeInCapacity"
  policy_type               = "StepScaling"
  estimated_instance_warmup = 200

  # Each of the step_adjustment values below defines what to do if the metric is a given amount above the alarm
  # threshold. Since our threshold is set at 75, the values below define what to do for CPU usage between 75 and 85%
  # and then anything above 85%

  step_adjustment {
    metric_interval_lower_bound = 0.0
    metric_interval_upper_bound = 10.0
    scaling_adjustment          = 1
  }

  step_adjustment {
    metric_interval_lower_bound = 10.0
    scaling_adjustment          = 2
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name        = "${var.cluster_name}-autoscaling-high-cpu-utilization"
  alarm_description = "An alarm that goes off if the CPU usage in the ${var.cluster_name} ECS cluster is high"
  namespace         = "AWS/EC2"
  metric_name       = "CPUUtilization"
  dimensions = {
    AutoScalingGroupName = module.ecs_cluster.ecs_cluster_asg_name
  }
  comparison_operator = var.high_cpu_utilization_comparison_operator
  evaluation_periods  = var.high_cpu_utilization_evaluation_periods
  period              = var.high_cpu_utilization_period
  statistic           = var.high_cpu_utilization_statistic
  threshold           = var.high_cpu_utilization_threshold
  unit                = var.high_cpu_utilization_unit
  alarm_actions       = [aws_autoscaling_policy.scale_out[count.index].arn]
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD AN AUTO SCALING POLICY TO REMOVE INSTANCES WHEN CPU USAGE IS LOW
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = module.ecs_cluster.ecs_cluster_asg_name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
  cooldown               = 200
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_utilization" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name        = "${var.cluster_name}-autoscaling-low-cpu-utilization"
  alarm_description = "An alarm that goes off if the CPU usage in the ${var.cluster_name} ECS cluster is low"
  namespace         = "AWS/EC2"
  metric_name       = "CPUUtilization"
  dimensions = {
    AutoScalingGroup = module.ecs_cluster.ecs_cluster_asg_name
  }
  comparison_operator = var.low_cpu_utilization_comparison_operator
  evaluation_periods  = var.low_cpu_utilization_evaluation_periods
  period              = var.low_cpu_utilization_period
  statistic           = var.low_cpu_utilization_statistic
  threshold           = var.low_cpu_utilization_threshold
  unit                = var.low_cpu_utilization_unit
  alarm_actions       = [aws_autoscaling_policy.scale_in[count.index].arn]
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
