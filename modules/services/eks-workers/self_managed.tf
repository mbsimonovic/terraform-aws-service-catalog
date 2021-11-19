# ---------------------------------------------------------------------------------------------------------------------
# CREATE SELF MANAGED WORKER POOL
# Provision ASGs to manage EKS worker pools with the necessary IAM permissions to communicate with the EKS control
# plane.
# ---------------------------------------------------------------------------------------------------------------------

module "self_managed_workers" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.46.4"

  # Ideally, we can use module count to drive this resource creation, but using module counts and for_each adds a
  # limitation where dependency chains apply at the module level, not the individual resources. This causes a cyclic
  # dependency in `eks-cluster` module as there is a back and forth dependency chain due to the aws-auth ConfigMap.
  create_resources = local.has_self_managed_workers

  cluster_name = var.eks_cluster_name
  name_prefix  = var.worker_name_prefix

  iam_role_already_exists   = var.asg_iam_role_already_exists
  iam_role_name             = local.asg_iam_role_name
  iam_role_arn              = var.asg_iam_role_arn
  iam_instance_profile_name = var.asg_iam_instance_profile_name

  autoscaling_group_configurations  = local.asg_configs
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
  asg_default_multi_instance_overrides                 = var.asg_default_multi_instance_overrides

  custom_tags_security_group = var.asg_security_group_tags

  # The following are not yet supported to accept multiple, but in a future version, we will support extracting
  # additional AMI configurations from each ASG entry.
  # NOTE: we don't configure asg_default_instance_user_data_base64 here because asg_configs will inject a user data
  # setting for every group configuration, negating the need to configure the default.
  asg_default_instance_ami = module.ec2_baseline_common.existing_ami

  cluster_instance_keypair_name = var.cluster_instance_keypair_name

  tenancy = var.tenancy

  # These are dangerous variables that are exposed to make testing easier, but should be left untouched.
  cluster_instance_associate_public_ip_address = var.cluster_instance_associate_public_ip_address

  # Backward compatibility flags
  use_resource_name_prefix = var.asg_use_resource_name_prefix
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

resource "aws_security_group_rule" "custom_ingress_security_group_rules_asg" {
  for_each = local.has_self_managed_workers ? var.custom_ingress_security_group_rules : {}

  type              = "ingress"
  security_group_id = module.self_managed_workers.eks_worker_security_group_id

  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  cidr_blocks              = each.value.cidr_blocks
}

resource "aws_security_group_rule" "custom_egress_security_group_rules_asg" {
  for_each = local.has_self_managed_workers ? var.custom_egress_security_group_rules : {}

  type              = "egress"
  security_group_id = module.self_managed_workers.eks_worker_security_group_id

  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.target_security_group_id
  cidr_blocks              = each.value.cidr_blocks
}

# Configure custom cloud-init configuration for each ASG depending on if cloud_init_parts, eks_kubelet_extra_args, or
# eks_bootstrap_script_options is configured on the asg.
data "cloudinit_config" "asg_cloud_inits" {
  for_each      = var.autoscaling_group_configurations
  gzip          = true
  base64_encode = true

  # NOTE: We extract out the default cloud init part first, and then render the rest. This ensures the default cloud
  # init configuration always runs first.
  part {
    filename     = "eks-worker-default-cloud-init"
    content_type = "text/x-shellscript"

    # Trim excess whitespace, because AWS will do that on deploy. This prevents
    # constant redeployment because the userdata hash doesn't match the trimmed
    # userdata hash.
    # See: https://github.com/hashicorp/terraform-provider-aws/issues/5011#issuecomment-878542063
    content = trimspace(templatefile(
      "${path.module}/user-data.sh",
      merge(
        local.default_user_data_context,
        {
          eks_kubelet_extra_args       = lookup(each.value, "eks_kubelet_extra_args", "")
          eks_bootstrap_script_options = lookup(each.value, "eks_bootstrap_script_options", "")
        },
      ),
    ))
  }

  dynamic "part" {
    for_each = merge(var.cloud_init_parts, lookup(each.value, "cloud_init_parts", {}))

    content {
      filename     = part.value.filename
      content_type = part.value.content_type
      content      = part.value.content
    }
  }
}

locals {
  # IAM role name should be null if IAM role arn is passed in.
  asg_iam_role_name = (
    var.asg_iam_role_arn != null
    ? null
    : (
      var.asg_custom_iam_role_name == null
      ? "${var.worker_name_prefix}${var.eks_cluster_name}-asg"
      : var.asg_custom_iam_role_name
    )
  )

  asg_configs = {
    for asg_name, asg_config in var.autoscaling_group_configurations :
    asg_name => merge(
      asg_config,
      { asg_instance_user_data_base64 = data.cloudinit_config.asg_cloud_inits[asg_name].rendered },
    )
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_self_managed_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.2"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from EC2
    for name in module.self_managed_workers.eks_worker_asg_names : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_self_managed_worker_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.2"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker MemoryUtilization"
  stat  = "Average"

  period = var.dashboard_memory_usage_widget_parameters.period
  width  = var.dashboard_memory_usage_widget_parameters.width
  height = var.dashboard_memory_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from cloudwatch-agent
    for name in module.self_managed_workers.eks_worker_asg_names : ["CWAgent", "mem_used_percent", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_self_managed_worker_disk_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.2"

  title = "${var.eks_cluster_name} Self-Managed EKSWorker DiskUtilization"
  stat  = "Average"

  period = var.dashboard_disk_usage_widget_parameters.period
  width  = var.dashboard_disk_usage_widget_parameters.width
  height = var.dashboard_disk_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from cloudwatch-agent
    for name in module.self_managed_workers.eks_worker_asg_names : ["CWAgent", "disk_used_percent", "AutoScalingGroupName", name, "MountPath", "/"]
  ]
}
