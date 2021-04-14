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
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }

    # Pin to this specific version to work around a bug introduced in 1.11.0:
    # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
    # (Only for EKS)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 1.10.0"
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
  load_config_file       = false
  host                   = data.template_file.kubernetes_cluster_endpoint.rendered
  cluster_ca_certificate = base64decode(data.template_file.kubernetes_cluster_ca.rendered)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}

# Workaround for Terraform limitation where you cannot directly set a depends on directive or interpolate from resources
# in the provider config.
# Specifically, Terraform requires all information for the Terraform provider config to be available at plan time,
# meaning there can be no computed resources. We work around this limitation by creating a template_file data source
# that does the computation.
# See https://github.com/hashicorp/terraform/issues/2430 for more details
data "template_file" "kubernetes_cluster_endpoint" {
  template = module.eks_cluster.eks_cluster_endpoint
}

data "template_file" "kubernetes_cluster_ca" {
  template = module.eks_cluster.eks_cluster_certificate_authority
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name = module.eks_cluster.eks_cluster_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE EKS CLUSTER WITH A WORKER POOL
# ---------------------------------------------------------------------------------------------------------------------

module "eks_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-control-plane?ref=v0.35.2"

  cluster_name = var.cluster_name

  vpc_id                       = var.vpc_id
  vpc_control_plane_subnet_ids = local.usable_control_plane_subnet_ids
  endpoint_public_access_cidrs = var.allow_inbound_api_access_from_cidr_blocks

  enabled_cluster_log_types              = var.enabled_control_plane_log_types
  kubernetes_version                     = var.kubernetes_version
  endpoint_public_access                 = var.endpoint_public_access
  secret_envelope_encryption_kms_key_arn = var.secret_envelope_encryption_kms_key_arn

  # Options for configuring control plane services on Fargate
  schedule_control_plane_services_on_fargate = var.schedule_control_plane_services_on_fargate
  vpc_worker_subnet_ids                      = local.usable_fargate_subnet_ids
  create_default_fargate_iam_role            = var.create_default_fargate_iam_role
  custom_fargate_iam_role_name               = var.custom_default_fargate_iam_role_name

  custom_tags_eks_cluster    = var.eks_cluster_tags
  custom_tags_security_group = var.eks_cluster_security_group_tags

  # We make sure the Fargate Profile for control plane services depend on the aws-auth ConfigMap with user IAM role
  # mappings so that we don't accidentally revoke access to the Kubernetes cluster before we make all the necessary
  # operations against the Kubernetes API to reschedule the control plane pods.
  # Note that this implicitly ensures that the AWS Auth Merger Fargate profile is created fully before the control plane
  # services Fargate profile is created, avoiding the concurrency issue with creating multiple Fargate profiles
  # simultaneously.
  fargate_profile_dependencies = [
    module.eks_k8s_role_mapping.aws_auth_config_map_name,
  ]
}

module "eks_workers" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.35.2"
  create_resources = local.has_self_managed_workers

  # Use the output from control plane module as the cluster name to ensure the module only looks up the information
  # after the cluster is provisioned.
  cluster_name = module.eks_cluster.eks_cluster_name

  autoscaling_group_configurations  = var.autoscaling_group_configurations
  include_autoscaler_discovery_tags = var.autoscaling_group_include_autoscaler_discovery_tags

  asg_default_min_size                        = var.asg_default_min_size
  asg_default_max_size                        = var.asg_default_max_size
  asg_default_instance_type                   = var.asg_default_instance_type
  asg_default_tags                            = var.asg_default_tags
  asg_default_instance_spot_price             = var.asg_default_instance_spot_price
  asg_default_instance_root_volume_size       = var.asg_default_instance_root_volume_size
  asg_default_instance_root_volume_type       = var.asg_default_instance_root_volume_type
  asg_default_instance_root_volume_encryption = var.asg_default_instance_root_volume_encryption

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
  security_group_id        = module.eks_workers.eks_worker_security_group_id
  source_security_group_id = each.key
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_cidr_blocks" {
  count = local.has_self_managed_workers && length(var.allow_inbound_ssh_from_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = module.eks_workers.eks_worker_security_group_id
  cidr_blocks       = var.allow_inbound_ssh_from_cidr_blocks
}

resource "aws_security_group_rule" "allow_private_endpoint_from_security_groups" {
  for_each = { for group_id in var.allow_private_api_access_from_security_groups : group_id => group_id }

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.eks_control_plane_security_group_id
  source_security_group_id = each.key
}

resource "aws_security_group_rule" "allow_private_endpoint_from_cidr_blocks" {
  count = length(var.allow_inbound_ssh_from_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = module.eks_cluster.eks_control_plane_security_group_id
  cidr_blocks       = var.allow_inbound_ssh_from_cidr_blocks
}

locals {
  has_self_managed_workers = length(var.autoscaling_group_configurations) > 0
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
  source           = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-aws-auth-merger?ref=v0.35.2"
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.35.2"

  # Configure to create this in the merger namespace if using the aws-auth-merger. Otherwise create it as the main
  # config.
  # NOTE: the hardcoded strings used when aws-auth-merger is disabled is important as that is what AWS expects this
  # ConfigMap to be named. The mapping and authentication will not work if you use a different Namespace or name.
  name      = var.enable_aws_auth_merger ? var.aws_auth_merger_default_configmap_name : "aws-auth"
  namespace = local.aws_auth_merger_namespace_name == null ? "kube-system" : local.aws_auth_merger_namespace_name

  eks_worker_iam_role_arns = (
    length(var.autoscaling_group_configurations) > 0
    ? [module.eks_workers.eks_worker_iam_role_arn]
    : []
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
  eks_fargate_profile_executor_iam_role_arns = (
    var.schedule_control_plane_services_on_fargate && var.enable_aws_auth_merger == false
    ? [module.eks_cluster.eks_default_fargate_execution_role_arn_without_dependency]
    : []
  )

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
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.26.1"

  title = "${var.cluster_name} EKSWorker CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    for name in module.eks_workers.eks_worker_asg_names : ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_worker_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.26.1"

  title = "${var.cluster_name} EKSWorker MemoryUtilization"
  stat  = "Average"

  period = var.dashboard_memory_usage_widget_parameters.period
  width  = var.dashboard_memory_usage_widget_parameters.width
  height = var.dashboard_memory_usage_widget_parameters.height

  metrics = [
    for name in module.eks_workers.eks_worker_asg_names : ["System/Linux", "MemoryUtilization", "AutoScalingGroupName", name]
  ]
}

module "metric_widget_worker_disk_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.26.1"

  title = "${var.cluster_name} EKSWorker DiskUtilization"
  stat  = "Average"

  period = var.dashboard_disk_usage_widget_parameters.period
  width  = var.dashboard_disk_usage_widget_parameters.width
  height = var.dashboard_disk_usage_widget_parameters.height

  metrics = [
    for name in module.eks_workers.eks_worker_asg_names : ["System/Linux", "DiskSpaceUtilization", "AutoScalingGroupName", name, "MountPath", "/"]
  ]
}


# ---------------------------------------------------------------------------------------------------------------------
# BASE RESOURCES
# Includes resources common to all EC2 instances in the Service Catalog, including permissions
# for ssh-grunt, CloudWatch Logs aggregation, CloudWatch metrics, and CloudWatch alarms
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name                                = var.cluster_name
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  enable_ssh_grunt                    = local.enable_ssh_grunt
  iam_role_name                       = module.eks_workers.eks_worker_iam_role_name
  enable_cloudwatch_metrics           = local.has_self_managed_workers && var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = local.has_self_managed_workers && var.enable_cloudwatch_alarms
  asg_names                           = module.eks_workers.eks_worker_asg_names
  num_asg_names                       = length(var.autoscaling_group_configurations)
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.cluster_instance_ami
  ami_filters                         = var.cluster_instance_ami_filters

  // CloudWatch log aggregation is handled separately in EKS
  enable_cloudwatch_log_aggregation = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT TO RUN ON EKS WORKERS WHEN IT BOOTS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "eks-worker-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)
  enable_ssh_grunt = (
    var.ssh_grunt_iam_group == "" && var.ssh_grunt_iam_group_sudo == ""
    ? false
    : local.has_self_managed_workers
  )

  base_user_data = templatefile(
    "${path.module}/user-data.sh",
    {
      aws_region                = data.aws_region.current.name
      eks_cluster_name          = var.cluster_name
      eks_endpoint              = module.eks_cluster.eks_cluster_endpoint
      eks_certificate_authority = module.eks_cluster.eks_cluster_certificate_authority

      enable_ssh_grunt                    = local.enable_ssh_grunt
      enable_fail2ban                     = var.enable_fail2ban
      ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
      ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
      external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn

      # We disable CloudWatch logs at the VM level as this is handled internally in k8s.
      enable_cloudwatch_log_aggregation = false
      log_group_name                    = ""

      # TODO: investigate if IP lockdown can now be enabled due to IRSA
      enable_ip_lockdown = false
    },
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_region" "current" {}


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
