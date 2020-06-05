# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS CLUSTER TO RUN DOCKER CONTAINERS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster" {
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-cluster?ref=v0.16.0"

  cluster_name     = var.cluster_name
  cluster_min_size = var.cluster_min_size
  cluster_max_size = var.cluster_max_size

  cluster_instance_ami          = var.cluster_instance_ami
  cluster_instance_type         = var.cluster_instance_type
  cluster_instance_keypair_name = var.cluster_instance_keypair_name
  cluster_instance_user_data    = data.template_file.user_data.rendered

  vpc_id                           = var.vpc_id
  vpc_subnet_ids                   = var.vpc_subnet_ids
  tenancy                          = var.tenancy
  allow_ssh                        = var.allow_ssh
  allow_ssh_from_security_group_id = var.openvpn_server_security_group_id

  alb_security_group_ids     = compact(concat(data.template_file.alb_public_security_group_ids.*.rendered, data.template_file.alb_internal_security_group_ids.*.rendered))
  num_alb_security_group_ids = (var.allow_requests_from_public_alb ? 1 : 0) + (var.allow_requests_from_internal_alb ? 1 : 0)
}

data "template_file" "alb_public_security_group_ids" {
  count    = var.allow_requests_from_public_alb ? 1 : 0
  template = var.alb_security_group_ids[count.index]
}

data "template_file" "alb_internal_security_group_ids" {
  count    = var.allow_requests_from_internal_alb ? 1 : 0
  template = var.alb_security_group_ids[count.index]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    aws_region       = var.aws_region
    ecs_cluster_name = var.cluster_name
    log_group_name   = var.cluster_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source      = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.13.2"
  name_prefix = var.cluster_name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_log_aggregation_policy" {
  name       = "attach-cloudwatch-log-aggregation-policy"
  roles      = [module.ecs_cluster.ecs_instance_iam_role_name]
  policy_arn = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD AWS SECRETS MANAGER PERMISSIONS 
# ---------------------------------------------------------------------------------------------------------------------

# TODO: The IAM permissions to use the KMS master key was removed per step 5 of these instructions
# It seems we were granting the ecs_instance_iam_role decrypt permissions on the key 
# Figure out which secrets in particular the ecs docker containers actually need and grant them access explicitly via AWS secrets manager permissions


# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source      = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.18.3
  "
  name_prefix = var.cluster_name

  # We set this to false so that the cloudwatch-custom-metrics-iam policy generates JSON for the policy, but does not create a standalone IAM policy with that JSON. We'll instead add that JSON to the ECS cluster IAM role. 
  create_resources = false 
}

resource "aws_iam_role_policy" "custom_cloudwatch_metrics" {
  count = var.enable_cloudwatch_metrics ? 1 : 0 
  name = "custom-cloudwatch-metrics"
  role = module.ecs_cluster.ecs_instance_iam_role_name
  policy = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions.json
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CLUSTER'S CPU, MEMORY, OR DISK SPACE USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_cluster_cpu_memory_alarms" {
  source               = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ecs-cluster-alarms?ref=v0.13.2"
  ecs_cluster_name     = var.cluster_name
  alarm_sns_topic_arns = [var.sns_region_arn]

  # These alarms will go off if CPU or memory usage is over 90 percent during a 5 minute period
  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "ecs_cluster_disk_memory_alarms" {
  source               = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.13.2"
  asg_names            = [module.ecs_cluster.ecs_cluster_asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = [data.terraform_remote_state.sns_region.outputs.arn]

  file_system = "/dev/xvda1"
  mount_path  = "/"

  # These alarms will go off if disk space usage is over 90 percent during a 5 minute period
  high_disk_utilization_threshold = var.high_disk_utilization_threshold
  high_disk_utilization_period    = var.high_disk_utilization_period
}

module "metric_widget_ecs_cluster_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.13.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.cluster_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name],
  ]
}

module "metric_widget_ecs_cluster_memory_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.13.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.cluster_name)} MemoryUtilization"

  metrics = [
    ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name],
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy to our ECS nodes that allows ssh-grunt to make API calls to IAM to fetch IAM user and group
# data.
# ---------------------------------------------------------------------------------------------------------------------

module "iam_policies" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.22.0"

  aws_account_id = var.aws_account_id

  # ssh-grunt is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  # Since our IAM users are defined in a separate AWS account, we need to give ssh-grunt permission to make API calls to
  # that account.
  allow_access_to_other_account_arns = [var.external_account_ssh_grunt_role_arn]
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  name   = "ssh-grunt-permissions"
  role   = module.ecs_cluster.ecs_instance_iam_role_name
  policy = module.iam_policies.allow_access_to_other_accounts[0]
}

