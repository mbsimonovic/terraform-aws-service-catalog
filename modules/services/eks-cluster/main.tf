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
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that has backwards incompatible changes that are known to NOT
  # work with the terraform-aws-eks repo. We are working on a fix, but until that's ready, we need to avoid 0.13.x.
  required_version = "~> 0.12.26"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-control-plane?ref=v0.26.0"

  cluster_name = var.cluster_name

  vpc_id                       = var.vpc_id
  vpc_control_plane_subnet_ids = var.control_plane_vpc_subnet_ids
  endpoint_public_access_cidrs = var.allow_inbound_api_access_from_cidr_blocks

  enabled_cluster_log_types              = var.enabled_control_plane_log_types
  kubernetes_version                     = var.kubernetes_version
  endpoint_public_access                 = var.endpoint_public_access
  secret_envelope_encryption_kms_key_arn = var.secret_envelope_encryption_kms_key_arn

  # Options for configuring control plane services on Fargate
  schedule_control_plane_services_on_fargate = var.schedule_control_plane_services_on_fargate
  vpc_worker_subnet_ids                      = var.worker_vpc_subnet_ids
}

module "eks_workers" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.26.0"
  create_resources = length(var.autoscaling_group_configurations) > 0

  # Use the output from control plane module as the cluster name to ensure the module only looks up the information
  # after the cluster is provisioned.
  cluster_name = module.eks_cluster.eks_cluster_name

  autoscaling_group_configurations  = var.autoscaling_group_configurations
  include_autoscaler_discovery_tags = var.autoscaling_group_include_autoscaler_discovery_tags

  cluster_instance_ami              = module.ec2_baseline.existing_ami
  cluster_instance_type             = var.cluster_instance_type
  cluster_instance_keypair_name     = var.cluster_instance_keypair_name
  cluster_instance_user_data_base64 = module.ec2_baseline.cloud_init_rendered

  tenancy = var.tenancy

  # These are dangerous variables that are exposed to make testing easier, but should be left untouched.
  cluster_instance_associate_public_ip_address = var.cluster_instance_associate_public_ip_address
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_security_groups" {
  for_each = { for group_id in var.allow_inbound_ssh_from_security_groups : group_id => group_id }

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.eks_workers.eks_worker_security_group_id
  source_security_group_id = each.key
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_cidr_blocks" {
  count = length(var.allow_inbound_ssh_from_cidr_blocks) > 0 ? 1 : 0

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


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE EKS IAM ROLE MAPPINGS
# We will map AWS IAM roles to RBAC roles in Kubernetes. By doing so, we:
# - allow access to the EKS cluster when assuming mapped IAM role
# - manage authorization for those roles using RBAC role resources in Kubernetes
# Here, we bind the following permissions:
# - The Worker IAM roles should have node level permissions
# - The full-access roles should have admin level permissions
# ---------------------------------------------------------------------------------------------------------------------

# EKS will automatically create the `aws-auth` config map when a Fargate profile is created before the configmap exists.
# This conflicts with the `eks-k8s-role-mapping` module, as terraform can only create the config map if it doesn't exist.
# Here, we use a null resource to delete the config map when the EKS cluster is first created.
resource "null_resource" "delete_autocreated_aws_auth" {
  count = var.schedule_control_plane_services_on_fargate ? 1 : 0

  triggers = {
    # We only want to run this on initial EKS cluster deployment.
    eks_cluster = module.eks_cluster.eks_cluster_arn
  }

  provisioner "local-exec" {
    command = join(
      " ",
      [
        module.eks_cluster.kubergrunt_path,
        "k8s",
        "kubectl",
        "--kubectl-eks-cluster-arn",
        module.eks_cluster.eks_cluster_arn,
        "--",
        "delete", "configmap", "aws-auth",
        "-n", "kube-system",
      ],
    )
  }
  depends_on = [module.eks_cluster]
}

module "eks_k8s_role_mapping" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.26.0"

  eks_worker_iam_role_arns = (
    length(var.autoscaling_group_configurations) > 0
    ? [module.eks_workers.eks_worker_iam_role_arn]
    : []
  )

  eks_fargate_profile_executor_iam_role_arns = (
    var.schedule_control_plane_services_on_fargate
    ? [module.eks_cluster.eks_default_fargate_execution_role_arn]
    : []
  )

  iam_role_to_rbac_group_mappings = var.iam_role_to_rbac_group_mapping
  iam_user_to_rbac_group_mappings = var.iam_user_to_rbac_group_mapping

  config_map_labels = {
    eks-cluster                        = module.eks_cluster.eks_cluster_name
    delete-original-aws-auth-action-id = var.schedule_control_plane_services_on_fargate ? null_resource.delete_autocreated_aws_auth[0].id : ""
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_worker_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.3"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.3"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.3"

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
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = var.enable_cloudwatch_alarms
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
  enable_ssh_grunt = var.ssh_grunt_iam_group == "" && var.ssh_grunt_iam_group_sudo == "" ? false : true

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
