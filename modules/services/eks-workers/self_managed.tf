# ---------------------------------------------------------------------------------------------------------------------
# CREATE SELF MANAGED WORKER POOL
# Provision ASGs to manage EKS worker pools with the necessary IAM permissions to communicate with the EKS control
# plane.
# ---------------------------------------------------------------------------------------------------------------------

module "self_managed_workers" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.41.0"
  create_resources = local.has_self_managed_workers

  cluster_name = var.eks_cluster_name
  name_prefix  = var.worker_name_prefix

  iam_role_already_exists = var.asg_iam_role_already_exists
  iam_role_name           = local.asg_iam_role_name

  autoscaling_group_configurations  = var.autoscaling_group_configurations
  include_autoscaler_discovery_tags = var.autoscaling_group_include_autoscaler_discovery_tags

  asg_default_min_size                                 = var.asg_default_min_size
  asg_default_max_size                                 = var.asg_default_max_size
  asg_default_instance_type                            = var.asg_default_instance_type
  asg_default_tags                                     = var.asg_default_tags
  asg_default_instance_root_volume_size                = var.asg_default_instance_root_volume_size
  asg_default_instance_root_volume_type                = var.asg_default_instance_root_volume_type
  asg_default_instance_root_volume_encryption          = var.asg_default_instance_root_volume_encryption
  asg_default_use_multi_instances_policy               = var.asg_default_use_multi_instances_policy
  asg_default_on_demand_allocation_strategy            = var.asg_default_on_demand_allocation_strategy
  asg_default_on_demand_base_capacity                  = var.asg_default_on_demand_base_capacity
  asg_default_on_demand_percentage_above_base_capacity = var.asg_default_on_demand_percentage_above_base_capacity
  asg_default_spot_allocation_strategy                 = var.asg_default_spot_allocation_strategy
  asg_default_spot_instance_pools                      = var.asg_default_spot_instance_pools
  asg_default_spot_max_price                           = var.asg_default_spot_max_price

  # The following are not yet supported to accept multiple, but in a future version, we will support extracting
  # additional user data and AMI configurations from each ASG entry.
  asg_default_instance_ami              = module.ec2_baseline.existing_ami
  asg_default_instance_user_data_base64 = module.ec2_baseline.cloud_init_rendered

  cluster_instance_keypair_name = var.cluster_instance_keypair_name

  tenancy = var.tenancy

  # These are dangerous variables that are exposed to make testing easier, but should be left untouched.
  cluster_instance_associate_public_ip_address = var.cluster_instance_associate_public_ip_address
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_security_groups" {
  for_each = (
    local.has_self_managed_workers
    ? { for group_id in var.allow_inbound_ssh_from_security_groups : group_id => group_id }
    : {}
  )

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.self_managed_workers.eks_worker_security_group_id
  source_security_group_id = each.key
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_cidr_blocks" {
  count = local.has_self_managed_workers && length(var.allow_inbound_ssh_from_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = module.self_managed_workers.eks_worker_security_group_id
  cidr_blocks       = var.allow_inbound_ssh_from_cidr_blocks
}

locals {
  asg_iam_role_name = (
    var.asg_custom_iam_role_name == null
    ? "${var.worker_name_prefix}${var.eks_cluster_name}-asg"
    : var.asg_custom_iam_role_name
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_self_managed_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.27.0"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    for name in module.self_managed_workers.eks_worker_asg_names : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_self_managed_worker_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.27.0"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker MemoryUtilization"
  stat  = "Average"

  period = var.dashboard_memory_usage_widget_parameters.period
  width  = var.dashboard_memory_usage_widget_parameters.width
  height = var.dashboard_memory_usage_widget_parameters.height

  metrics = [
    for name in module.self_managed_workers.eks_worker_asg_names : ["System/Linux", "MemoryUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_self_managed_worker_disk_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.27.0"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker DiskUtilization"
  stat  = "Average"

  period = var.dashboard_disk_usage_widget_parameters.period
  width  = var.dashboard_disk_usage_widget_parameters.width
  height = var.dashboard_disk_usage_widget_parameters.height

  metrics = [
    for name in module.self_managed_workers.eks_worker_asg_names : ["System/Linux", "DiskSpaceUtilization", "AutoScalingGroupName", name, "MountPath", "/"]
  ]
}
