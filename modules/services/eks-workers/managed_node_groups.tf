# ---------------------------------------------------------------------------------------------------------------------
# CREATE MANAGED NODE GROUP WORKER POOL
# Provision Managed Node Groups to manage EKS worker pools, including launch templates.
# ---------------------------------------------------------------------------------------------------------------------

module "managed_node_groups" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-managed-workers?ref=v0.46.9"

  # Ideally, we can use module count to drive this resource creation, but using module counts and for_each adds a
  # limitation where dependency chains apply at the module level, not the individual resources. This causes a cyclic
  # dependency in `eks-cluster` module as there is a back and forth dependency chain due to the aws-auth ConfigMap.
  create_resources = local.has_managed_node_groups

  cluster_name = var.eks_cluster_name
  name_prefix  = var.worker_name_prefix

  iam_role_already_exists = var.managed_node_group_iam_role_already_exists
  iam_role_name           = local.managed_node_group_iam_role_name
  iam_role_arn            = var.managed_node_group_iam_role_arn

  # Since the node group configurations include launch template resources, we need to provide the names of the node
  # groups separately using only the variable.
  node_group_names = (
    var.node_group_names == null
    ? [for name, config in var.managed_node_group_configurations : name]
    : var.node_group_names
  )
  node_group_configurations = (
    # We want to make sure the role mapping config map is created before the Managed Node Groups to avoid conflicts with
    # EKS automatically updating the auth config map with the IAM role. Otherwise, the aws-auth-merger will crash. To
    # do this, we add an artificial dependency here using a tautology. Note that we can't use module depends_on because
    # the IAM role used in the role mapping is created within this module block.
    length(module.eks_k8s_role_mapping) > 0
    ? (
      module.eks_k8s_role_mapping["enable"].aws_auth_config_map_name == null
      ? local.node_group_configurations_with_launch_template
      : local.node_group_configurations_with_launch_template
    )
    : local.node_group_configurations_with_launch_template
  )

  node_group_default_subnet_ids     = var.node_group_default_subnet_ids
  node_group_default_min_size       = var.node_group_default_min_size
  node_group_default_max_size       = var.node_group_default_max_size
  node_group_default_desired_size   = var.node_group_default_desired_size
  node_group_default_instance_types = var.node_group_default_instance_types
  node_group_default_capacity_type  = var.node_group_default_capacity_type
  node_group_default_tags           = var.node_group_default_tags
  node_group_default_labels         = var.node_group_default_labels
}

resource "aws_launch_template" "template" {
  for_each = var.managed_node_group_configurations

  name_prefix   = var.eks_cluster_name
  instance_type = var.node_group_launch_template_instance_type
  key_name      = var.cluster_instance_keypair_name

  user_data = data.cloudinit_config.managed_node_group[each.key].rendered

  # For now, each Managed Node Group must have the same AMI. In a future version, we will support extracting additional
  # AMI configurations from each Managed Node Group entry.
  image_id = module.ec2_baseline_common.existing_ami

  network_interfaces {
    security_groups = concat(
      [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id],
      aws_security_group.managed_node_group[*].id,
      var.additional_security_groups_for_workers,
    )

    # This setting exists solely for testing purposes. For production usage, you should not expose the worker nodes
    # publicly and instead rely on the EKS Control Plane and ELBs for public access.
    associate_public_ip_address = var.cluster_instance_associate_public_ip_address
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(each.value, "instance_root_volume_size", var.node_group_default_instance_root_volume_size)
      volume_type = lookup(each.value, "instance_root_volume_type", var.node_group_default_instance_root_volume_type)
      encrypted   = lookup(each.value, "instance_root_volume_encryption", var.node_group_default_instance_root_volume_encryption)
    }
  }
}

locals {
  node_group_configurations_with_launch_template = {
    for name, config in var.managed_node_group_configurations :
    name => merge(
      {
        launch_template = {
          id      = aws_launch_template.template[name].id
          version = aws_launch_template.template[name].latest_version
          # We are selecting the launch template by id, so set the name attribute to null.
          name = null
        }
      },
      config,
    )
  }

  # When selecting default IAM role name, use a different IAM role name for each worker type to avoid conflicting.
  managed_node_group_default_iam_role_name = "${var.worker_name_prefix}${var.eks_cluster_name}-mng"
  # IAM role name should be null if IAM role arn is passed in.
  managed_node_group_iam_role_name = (
    var.managed_node_group_iam_role_arn != null
    ? null
    : (
      var.managed_node_group_custom_iam_role_name == null
      ? local.managed_node_group_default_iam_role_name
      : var.managed_node_group_custom_iam_role_name
    )
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP CLOUDINIT CONFIG
# Managed node groups need a specialized cloud-init configuration. See
# https://github.com/hashicorp/terraform-provider-aws/issues/15007 for more info.
# ---------------------------------------------------------------------------------------------------------------------

data "cloudinit_config" "managed_node_group" {
  for_each = var.managed_node_group_configurations

  gzip          = false
  base64_encode = true
  boundary      = "==BOUNDARY=="

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

# ---------------------------------------------------------------------------------------------------------------------
# SET UP SECURITY GROUP FOR SSH ACCESS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "managed_node_group" {
  count       = local.has_managed_node_groups ? 1 : 0
  name        = "${var.worker_name_prefix}${var.eks_cluster_name}-mng"
  description = "Security group for managing access to EC2 instances of Managed Node Groups of cluster ${var.eks_cluster_name}."
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  tags        = var.node_group_security_group_tags
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_security_groups_mng" {
  for_each = (
    local.has_managed_node_groups
    ? { for group_id in var.allow_inbound_ssh_from_security_groups : group_id => group_id }
    : {}
  )

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.managed_node_group[0].id
  source_security_group_id = each.key
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_cidr_blocks_mng" {
  count = local.has_managed_node_groups && length(var.allow_inbound_ssh_from_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.managed_node_group[0].id
  cidr_blocks       = var.allow_inbound_ssh_from_cidr_blocks
}

resource "aws_security_group_rule" "custom_ingress_security_group_rules_mng" {
  for_each = local.has_managed_node_groups ? var.custom_ingress_security_group_rules : {}

  type              = "ingress"
  security_group_id = aws_security_group.managed_node_group[0].id

  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  cidr_blocks              = each.value.cidr_blocks
}

resource "aws_security_group_rule" "custom_egress_security_group_rules_mng" {
  for_each = local.has_managed_node_groups ? var.custom_egress_security_group_rules : {}

  type              = "egress"
  security_group_id = aws_security_group.managed_node_group[0].id

  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.target_security_group_id
  cidr_blocks              = each.value.cidr_blocks
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

locals {
  managed_node_group_asg_names = flatten([for name, asg_names in module.managed_node_groups.eks_worker_asg_names : asg_names])
}

module "metric_widget_managed_node_group_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.eks_cluster_name} Managed Node Group EKSWorker CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from EC2
    for name in local.managed_node_group_asg_names : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_managed_node_group_worker_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.eks_cluster_name} Managed Node Group EKSWorker MemoryUtilization"
  stat  = "Average"

  period = var.dashboard_memory_usage_widget_parameters.period
  width  = var.dashboard_memory_usage_widget_parameters.width
  height = var.dashboard_memory_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from cloudwatch-agent
    for name in local.managed_node_group_asg_names : ["CWAgent", "mem_used_percent", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_managed_node_group_worker_disk_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.eks_cluster_name} Managed Node Group EKSWorker DiskUtilization"
  stat  = "Average"

  period = var.dashboard_disk_usage_widget_parameters.period
  width  = var.dashboard_disk_usage_widget_parameters.width
  height = var.dashboard_disk_usage_widget_parameters.height

  metrics = [
    # The metric namespace and name come from cloudwatch-agent
    for name in local.managed_node_group_asg_names : ["CWAgent", "disk_used_percent", "AutoScalingGroupName", name, "MountPath", "/"]
  ]
}
