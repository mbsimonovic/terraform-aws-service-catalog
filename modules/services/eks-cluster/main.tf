# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN EKS CLUSTER TO RUN DOCKER CONTAINERS
# This module can be used to deploy an EKS cluster with either self-managed workers or Fargate workers. It creates the
# following resources:
#
# - An EKS Control Plane
# - ASGs of self-managed workers
# - IAM role to RBAC group mappings for authentication
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.13.7 as the minimum version, as that version added support for module for_each, and includes the latest GPG key
  # for provider binary validation.
  required_version = ">= 0.13.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }

    # The underlying modules are only compatible with kubernetes provider 2.x
    kubernetes = {
      source = "hashicorp/kubernetes"
      # NOTE: 2.6.0 has a regression bug that prevents usage of the exec block with data source references, so we ignore
      # that in the version constraint. See https://github.com/hashicorp/terraform-provider-kubernetes/issues/1464 for
      # more details.
      version = "~> 2.0, != 2.6.0"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE KUBERNETES CONNECTION TO SETUP IAM ROLE MAPPING
# Note that we can't configure our Kubernetes connection until EKS is up and running, so we try to depend on the
# resource being created.
# ---------------------------------------------------------------------------------------------------------------------

# The provider needs to depend on the cluster being setup.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = var.use_exec_plugin_for_auth ? null : data.aws_eks_cluster_auth.kubernetes_token[0].token

  # EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To
  # avoid this issue, we use an exec-based plugin here to fetch an up-to-date token. Note that this code requires a
  # binary—either kubergrunt or aws—to be installed and on your PATH.
  dynamic "exec" {
    for_each = var.use_exec_plugin_for_auth ? ["once"] : []

    content {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = var.use_kubergrunt_to_fetch_token ? "kubergrunt" : "aws"
      args = (
        var.use_kubergrunt_to_fetch_token
        ? ["eks", "token", "--cluster-id", data.aws_eks_cluster.cluster.name]
        : ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
      )
    }
  }
}

# Workaround for Terraform limitation where you cannot directly set a depends on directive or interpolate from resources
# in the provider config.
# Specifically, Terraform requires all information for the Terraform provider config to be available at plan time,
# meaning there can be no computed resources. We work around this limitation by rereading the EKS cluster info using a
# data source.
# See https://github.com/hashicorp/terraform/issues/2430 for more details
data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.eks_cluster_name
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  count = var.use_exec_plugin_for_auth ? 0 : 1
  name  = module.eks_cluster.eks_cluster_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE EKS CLUSTER WITH A WORKER POOL
# ---------------------------------------------------------------------------------------------------------------------

module "eks_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-control-plane?ref=v0.48.0"

  cluster_name = var.cluster_name

  vpc_id                        = var.vpc_id
  vpc_control_plane_subnet_ids  = local.usable_control_plane_subnet_ids
  endpoint_public_access_cidrs  = var.allow_inbound_api_access_from_cidr_blocks
  endpoint_private_access_cidrs = var.allow_private_api_access_from_cidr_blocks
  endpoint_private_access_security_group_ids = {
    for group_id in var.allow_private_api_access_from_security_groups :
    group_id => group_id
  }

  # VPC CNI Customization options
  use_vpc_cni_customize_script     = var.use_vpc_cni_customize_script
  vpc_cni_enable_prefix_delegation = var.vpc_cni_enable_prefix_delegation
  vpc_cni_warm_ip_target           = var.vpc_cni_warm_ip_target
  vpc_cni_minimum_ip_target        = var.vpc_cni_minimum_ip_target

  # Control Plane logging configuration
  enabled_cluster_log_types              = var.enabled_control_plane_log_types
  should_create_cloudwatch_log_group     = var.should_create_control_plane_cloudwatch_log_group
  cloudwatch_log_group_retention_in_days = var.control_plane_cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = var.control_plane_cloudwatch_log_group_kms_key_id
  cloudwatch_log_group_tags              = var.control_plane_cloudwatch_log_group_tags

  kubernetes_version                     = var.kubernetes_version
  endpoint_public_access                 = var.endpoint_public_access
  secret_envelope_encryption_kms_key_arn = var.secret_envelope_encryption_kms_key_arn
  additional_security_groups             = var.additional_security_groups_for_control_plane

  # Options for configuring control plane services on Fargate
  schedule_control_plane_services_on_fargate = var.schedule_control_plane_services_on_fargate
  vpc_worker_subnet_ids                      = local.usable_fargate_subnet_ids
  create_default_fargate_iam_role            = var.create_default_fargate_iam_role
  custom_fargate_iam_role_name               = var.custom_default_fargate_iam_role_name

  custom_tags_eks_cluster    = var.eks_cluster_tags
  custom_tags_security_group = var.eks_cluster_security_group_tags

  cluster_iam_role_permissions_boundary = var.cluster_iam_role_permissions_boundary

  # We make sure the Fargate Profile for control plane services depend on the aws-auth ConfigMap with user IAM role
  # mappings so that we don't accidentally revoke access to the Kubernetes cluster before we make all the necessary
  # operations against the Kubernetes API to reschedule the control plane pods.
  # Note that this implicitly ensures that the AWS Auth Merger Fargate profile is created fully before the control plane
  # services Fargate profile is created, avoiding the concurrency issue with creating multiple Fargate profiles
  # simultaneously.
  fargate_profile_dependencies = [
    module.eks_k8s_role_mapping.aws_auth_config_map_name,
  ]

  # Feature flags
  use_kubergrunt_verification = var.use_kubergrunt_verification
  use_upgrade_cluster_script  = var.use_kubergrunt_sync_components
}

# This null_resource is a hack to avoid depends_on on modules. When you use a depends_on on a module, there is an
# undesirable side effect where all data source lookups within the module are deferred to apply time as opposed to plan
# time. This leads to tainting all resources within the module for change all the time (perpetual diff). To avoid this,
# we use implicit dependency links on the resources by linking core variables that all resources within the module uses
# to this null resource via a tautology.
resource "null_resource" "depend_on_auth_merger" {
  # We must wait for the aws-auth-merger to be available in order to start provisioning the workers.
  depends_on = [module.eks_aws_auth_merger]
}

module "eks_workers" {
  source = "../eks-workers"
  # The contents of the for_each is irrelevant, as it is only used to enable or disable the module.
  for_each = local.has_workers ? { enabled = true } : {}

  # Use the output from control plane module as the cluster name to ensure the module only looks up the information
  # after the cluster is provisioned.
  # NOTE: We use a tautology here that links this input variable to the null_resource above so that the workers aren't
  # created until the auth merger is ready.
  eks_cluster_name = (
    null_resource.depend_on_auth_merger.id == null ? module.eks_cluster.eks_cluster_name : module.eks_cluster.eks_cluster_name
  )

  # Self-managed workers settings
  autoscaling_group_configurations                     = var.autoscaling_group_configurations
  autoscaling_group_include_autoscaler_discovery_tags  = var.autoscaling_group_include_autoscaler_discovery_tags
  asg_iam_role_already_exists                          = local.has_self_managed_workers
  asg_iam_role_arn                                     = length(aws_iam_role.self_managed_worker) > 0 ? aws_iam_role.self_managed_worker[0].arn : null
  asg_iam_instance_profile_name                        = var.asg_iam_instance_profile_name
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
  asg_security_group_tags                              = var.asg_security_group_tags
  tenancy                                              = var.tenancy
  # Backward compatibility flags
  asg_use_resource_name_prefix = var.asg_use_resource_name_prefix

  # Managed Node Groups settings
  # We want to make sure the role mapping config map is created before the Managed Node Groups to avoid conflicts with
  # EKS automatically updating the auth config map with the IAM role. To do this, we add an artificial dependency here
  # using a tautology. Note that we can't use module depends_on because the IAM role used in the role mapping is created
  # within this module block.
  managed_node_group_configurations = (
    module.eks_k8s_role_mapping.aws_auth_config_map_name == null
    ? var.managed_node_group_configurations
    : var.managed_node_group_configurations
  )
  # Since managed_node_group_configurations now depends on a resources (the aws-auth ConfigMap), we need to assist the
  # module for_each calculation by providing values that are only derived from variables.
  node_group_names = [for name, config in var.managed_node_group_configurations : name]
  # The rest configure the defaults for the node group configurations.
  managed_node_group_iam_role_already_exists = local.has_managed_node_groups
  managed_node_group_iam_role_arn            = length(aws_iam_role.managed_node_group) > 0 ? aws_iam_role.managed_node_group[0].arn : null
  node_group_default_subnet_ids              = var.node_group_default_subnet_ids
  node_group_default_min_size                = var.node_group_default_min_size
  node_group_default_max_size                = var.node_group_default_max_size
  node_group_default_desired_size            = var.node_group_default_desired_size
  node_group_launch_template_instance_type   = var.node_group_launch_template_instance_type
  node_group_default_instance_types          = var.node_group_default_instance_types
  node_group_default_capacity_type           = var.node_group_default_capacity_type
  node_group_default_tags                    = var.node_group_default_tags
  node_group_default_labels                  = var.node_group_default_labels
  node_group_security_group_tags             = var.node_group_security_group_tags

  # The rest of the block specifies settings that are common to both worker groups

  worker_name_prefix        = var.worker_name_prefix
  aws_auth_merger_namespace = var.enable_aws_auth_merger ? var.aws_auth_merger_namespace : null

  # - AMI settings
  cluster_instance_ami         = var.cluster_instance_ami
  cluster_instance_ami_filters = var.cluster_instance_ami_filters
  cloud_init_parts             = var.cloud_init_parts

  # - VPC CNI options
  use_prefix_mode_to_calculate_max_pods = var.vpc_cni_enable_prefix_delegation

  # - Security group settings
  additional_security_groups_for_workers = var.additional_security_groups_for_workers
  allow_inbound_ssh_from_cidr_blocks     = var.allow_inbound_ssh_from_cidr_blocks
  allow_inbound_ssh_from_security_groups = var.allow_inbound_ssh_from_security_groups
  custom_ingress_security_group_rules    = var.custom_worker_ingress_security_group_rules
  custom_egress_security_group_rules     = var.custom_worker_egress_security_group_rules

  # - SSH settings
  cluster_instance_keypair_name       = var.cluster_instance_keypair_name
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
  ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
  enable_fail2ban                     = var.enable_fail2ban

  # - Monitoring settings
  enable_cloudwatch_metrics = var.enable_cloudwatch_metrics
  enable_cloudwatch_alarms  = var.enable_cloudwatch_alarms
  alarms_sns_topic_arn      = var.alarms_sns_topic_arn

  # - Dashboard widget settings
  dashboard_cpu_usage_widget_parameters    = var.dashboard_cpu_usage_widget_parameters
  dashboard_memory_usage_widget_parameters = var.dashboard_memory_usage_widget_parameters
  dashboard_disk_usage_widget_parameters   = var.dashboard_disk_usage_widget_parameters

  # - Kubernetes provider configuration parameters
  use_exec_plugin_for_auth      = var.use_exec_plugin_for_auth
  use_kubergrunt_to_fetch_token = var.use_kubergrunt_to_fetch_token

  # These are dangerous variables that are exposed to make testing easier, but should be left untouched.
  cluster_instance_associate_public_ip_address = var.cluster_instance_associate_public_ip_address
}

# Precreate the IAM roles for workers to avoid cyclic dependencies between the role mapping ConfigMap and ASGs/Node
# Groups. This avoids a dependency chain that crosses module boundaries, which can lead to weird bugs in terraform.
# Without this, you end up with the following dependency chain (note how the modules have interdependencies between each
# other):
#
# - ConfigMap in module.eks_k8s_role_mapping depends on IAM role in module.eks_workers
# - Node Group and ASG in module.eks_workers depends on ConfigMap in module.eks_k8s_role_mapping
#
# By introducing the aws_iam_role here, the dependency flattens to:
#
# - Node Group and ASG depends on aws_iam_role that is passed in.
# - ConfigMap in module.eks_k8s_role_mapping depends on aws_iam_role that is passed in.
#
resource "aws_iam_role" "self_managed_worker" {
  count                = local.has_self_managed_workers ? 1 : 0
  name                 = local.asg_iam_role_name
  assume_role_policy   = data.aws_iam_policy_document.allow_ec2_instances_to_assume_role.json
  permissions_boundary = var.asg_iam_permissions_boundary
}

resource "aws_iam_role" "managed_node_group" {
  count                = local.has_managed_node_groups ? 1 : 0
  name                 = local.managed_node_group_iam_role_name
  assume_role_policy   = data.aws_iam_policy_document.allow_ec2_instances_to_assume_role.json
  permissions_boundary = var.node_group_iam_permissions_boundary
}

data "aws_iam_policy_document" "allow_ec2_instances_to_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

locals {
  has_workers              = local.has_self_managed_workers || local.has_managed_node_groups
  has_self_managed_workers = length(var.autoscaling_group_configurations) > 0
  has_managed_node_groups  = length(var.managed_node_group_configurations) > 0

  # Use a different IAM role name for each worker type to avoid conflicting.
  managed_node_group_iam_role_name = "${var.worker_name_prefix}${var.cluster_name}-mng"
  asg_iam_role_name                = "${var.worker_name_prefix}${var.cluster_name}-asg"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE EKS IAM ROLE MAPPINGS
# We will map AWS IAM roles to RBAC roles in Kubernetes. By doing so, we:
# - allow access to the EKS cluster when assuming mapped IAM role
# - manage authorization for those roles using RBAC role resources in Kubernetes
# Here, we bind the following permissions:
# - The Worker IAM roles should have node level permissions
# - The full-access roles should have admin level permissions
# ---------------------------------------------------------------------------------------------------------------------

# We create the namespace outside of the eks-aws-auth-merger module so that we can bind a dependency.
resource "kubernetes_namespace" "aws_auth_merger" {
  count = var.enable_aws_auth_merger ? 1 : 0
  metadata {
    name = (
      # We use the following tautology to ensure that the namespace only depends on the EKS cluster. This is necessary
      # to avoid cyclic dependencies with the aws-auth ConfigMap and the control plane services Fargate Profile.
      module.eks_cluster.eks_cluster_arn == null
      ? var.aws_auth_merger_namespace
      : var.aws_auth_merger_namespace
    )
  }
}

module "eks_aws_auth_merger" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-aws-auth-merger?ref=v0.48.0"
  create_resources = var.enable_aws_auth_merger

  create_namespace       = false
  namespace              = local.aws_auth_merger_namespace_name
  aws_auth_merger_image  = var.aws_auth_merger_image
  create_fargate_profile = var.enable_aws_auth_merger_fargate
  fargate_profile = {
    name                   = var.aws_auth_merger_namespace
    eks_cluster_name       = module.eks_cluster.eks_cluster_name
    worker_subnet_ids      = local.usable_fargate_subnet_ids
    pod_execution_role_arn = module.eks_cluster.eks_default_fargate_execution_role_arn_without_dependency
  }
}

module "eks_k8s_role_mapping" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.48.0"

  # Configure to create this in the merger namespace if using the aws-auth-merger. Otherwise create it as the main
  # config.
  # NOTE: the hardcoded strings used when aws-auth-merger is disabled are important as that is what AWS expects this
  # ConfigMap to be named. The mapping and authentication will not work if you use a different Namespace or name.
  name      = var.enable_aws_auth_merger ? var.aws_auth_merger_default_configmap_name : "aws-auth"
  namespace = local.aws_auth_merger_namespace_name == null ? "kube-system" : local.aws_auth_merger_namespace_name

  # Combine the default worker pool IAM role ARNs with the user provided IAM role ARNs.
  eks_worker_iam_role_arns = concat(
    # If aws-auth-merger is enabled and the user has requested workers, the worker IAM role mappings will be managed
    # within eks-workers module as separate ConfigMaps, so we don't need to manage the worker IAM role arns in the main
    # ConfigMap.
    (
      var.enable_aws_auth_merger == false
      ? concat(
        aws_iam_role.self_managed_worker[*].arn,
        aws_iam_role.managed_node_group[*].arn,
      )
      : []
    ),
    var.worker_iam_role_arns_for_k8s_role_mapping,
  )

  # Include the fargate executor IAM roles if we aren't using the aws-auth-merger.
  # AWS will automatically create an aws-auth ConfigMap that allows the Fargate nodes, so we won't configure it here.
  # The aws-auth-merger will automatically include that configuration if it sees the ConfigMap as it is booting up.
  # This works because we are creating a Fargate Profile BEFORE the aws-auth-merger is deployed
  # (`create_fargate_profile = true` in the `eks-aws-auth-merger` module call), which will cause EKS to create the
  # aws-auth ConfigMap to allow the Fargate workers to access the control plane. So the flow is:
  # 1. AWS creates central ConfigMap with the Fargate execution role.
  # 2. aws-auth-merger is deployed and starts up.
  # 3. aws-auth-merger sees the automatically created ConfigMap, detects that it is not managed by itself, and snapshots
  #    the ConfigMap to preserve the Fargate role mappings during future merges.
  # 4. aws-auth-merger looks up the other ConfigMaps in the namespace and merges them together to replace the existing
  #    central ConfigMap.
  # NOTE: we use compact here in case there is no fargate execution role created within the eks-cluster-control-plane
  # module.
  eks_fargate_profile_executor_iam_role_arns = compact(concat(
    (
      var.enable_aws_auth_merger == false
      ? [module.eks_cluster.eks_default_fargate_execution_role_arn_without_dependency]
      : []
    ),
    var.fargate_profile_executor_iam_role_arns_for_k8s_role_mapping,
  ))

  iam_role_to_rbac_group_mappings = var.iam_role_to_rbac_group_mapping
  iam_user_to_rbac_group_mappings = var.iam_user_to_rbac_group_mapping

  config_map_labels = {
    eks-cluster = module.eks_cluster.eks_cluster_name
  }
}

locals {
  aws_auth_merger_namespace_name = (
    length(kubernetes_namespace.aws_auth_merger) > 0
    ? kubernetes_namespace.aws_auth_merger[0].metadata[0].name
    : null
  )
}


# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE THE SUBNETS TO USE
# Since EKS has restrictions by availability zones, we need to support filtering out the provided subnets that do not
# support EKS. Which subnets are allowed is based on the disallowed availability zones input.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_subnet" "provided_for_control_plane" {
  count = var.num_control_plane_vpc_subnet_ids == null ? length(var.control_plane_vpc_subnet_ids) : var.num_control_plane_vpc_subnet_ids
  id    = var.control_plane_vpc_subnet_ids[count.index]
}

data "aws_subnet" "provided_for_fargate_workers" {
  count = var.num_worker_vpc_subnet_ids == null ? length(var.worker_vpc_subnet_ids) : var.num_worker_vpc_subnet_ids
  id    = var.worker_vpc_subnet_ids[count.index]
}

locals {
  usable_control_plane_subnet_ids = [
    for subnet in data.aws_subnet.provided_for_control_plane :
    subnet.id if contains(var.control_plane_disallowed_availability_zones, subnet.availability_zone) == false
  ]

  usable_fargate_subnet_ids = [
    for subnet in data.aws_subnet.provided_for_fargate_workers :
    subnet.id if contains(var.fargate_worker_disallowed_availability_zones, subnet.availability_zone) == false
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.cluster_name} EKSWorker CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = (
    local.has_workers
    ? [
      # The metric namespace and name come from EC2
      for name in module.eks_workers["enabled"].worker_asg_names : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", name]
    ]
    : []
  )
}

module "metric_widget_worker_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.cluster_name} EKSWorker MemoryUtilization"
  stat  = "Average"

  period = var.dashboard_memory_usage_widget_parameters.period
  width  = var.dashboard_memory_usage_widget_parameters.width
  height = var.dashboard_memory_usage_widget_parameters.height

  metrics = (
    local.has_workers
    ? [
      # The metric namespace and name come from cloudwatch-agent
      for name in module.eks_workers["enabled"].worker_asg_names : ["CWAgent", "mem_used_percent", "AutoScalingGroupName", name]
    ]
    : []
  )
}

module "metric_widget_worker_disk_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.cluster_name} EKSWorker DiskUtilization"
  stat  = "Average"

  period = var.dashboard_disk_usage_widget_parameters.period
  width  = var.dashboard_disk_usage_widget_parameters.width
  height = var.dashboard_disk_usage_widget_parameters.height

  metrics = (
    local.has_workers
    ? [
      # The metric namespace and name come from cloudwatch-agent
      for name in module.eks_workers["enabled"].worker_asg_names : ["CWAgent", "disk_used_percent", "AutoScalingGroupName", name, "MountPath", "/"]
    ]
    : []
  )
}
