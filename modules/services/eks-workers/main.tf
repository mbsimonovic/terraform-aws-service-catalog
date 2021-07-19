# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE WORKER GROUPS FOR EKS
# These templates create self-managed and/or managed worker groups for EKS to run containers for Kubernetes.
# The templates are broken up as follows:
# - main.tf                : EC2 baseline and computations to simplify logic.
# - self_managed.tf        : Resources for configuring self managed worker groups.
# - managed_node_groups.tf : Resources for configuring managed node groups.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.13.0 as the minimum version, as that version added support for module for_each.
  required_version = ">= 0.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

locals {
  has_self_managed_workers = length(var.autoscaling_group_configurations) > 0
  has_managed_node_groups  = length(var.managed_node_group_configurations) > 0
  worker_asg_names = concat(
    module.self_managed_workers.eks_worker_asg_names,
    local.managed_node_group_asg_names,
  )
  enable_ssh_grunt = var.ssh_grunt_iam_group != "" || var.ssh_grunt_iam_group_sudo != ""
}


# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCE LOOK UPS
# ---------------------------------------------------------------------------------------------------------------------

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  count = var.use_exec_plugin_for_auth ? 0 : 1
  name  = var.eks_cluster_name
}

data "aws_region" "current" {}


# ---------------------------------------------------------------------------------------------------------------------
# BASE RESOURCES
# Includes resources common to all EC2 instances in the Service Catalog, including permissions
# for ssh-grunt, CloudWatch Logs aggregation, CloudWatch metrics, and CloudWatch alarms
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name = join(
    "-",
    compact([var.eks_cluster_name, var.worker_name_prefix]),
  )

  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  enable_ssh_grunt                    = local.enable_ssh_grunt
  iam_role_name                       = module.self_managed_workers.eks_worker_iam_role_name
  enable_cloudwatch_metrics           = local.has_self_managed_workers && var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = local.has_self_managed_workers && var.enable_cloudwatch_alarms
  asg_names                           = local.worker_asg_names
  num_asg_names                       = length(var.autoscaling_group_configurations) + length(var.managed_node_group_configurations)
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.cluster_instance_ami
  ami_filters                         = var.cluster_instance_ami_filters

  // CloudWatch log aggregation is handled separately in EKS
  enable_cloudwatch_log_aggregation = false
}

# Logic to setup the user data script
locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "eks-worker-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  base_user_data = templatefile(
    "${path.module}/user-data.sh",
    {
      aws_region                = data.aws_region.current.name
      eks_cluster_name          = var.eks_cluster_name
      eks_endpoint              = data.aws_eks_cluster.cluster.endpoint
      eks_certificate_authority = data.aws_eks_cluster.cluster.certificate_authority.0.data

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
# CONFIGURE EKS IAM ROLE MAPPINGS
# Setup a Kubernetes ConfigMap that maps the worker pool IAM role to the RBAC groups that allow the EC2 instances to
# function as Kubernetes Nodes.
# This assumes the AWS Auth Merger is deployed. Otherwise, the user must manually configure the main ConfigMap to
# include the worker IAM role.
# ---------------------------------------------------------------------------------------------------------------------

# MAINTAINER'S NOTE: We configure this for both self-managed and managed node groups. Typically, it is not necessary to
# configure the aws-auth ConfigMap with the IAM role of managed node groups as AWS automatically updates the ConfigMap
# behind the scenes. However, when using aws-auth-merger, that out of band update may get lost when the ConfigMap is
# merged together. Therefore, to prevent data loss, we add the ConfigMap for self-managed workers when aws-auth-merger
# is in use.

module "eks_k8s_role_mapping" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.42.2"

  # Only setup the mapping if AWS Auth Merger is deployed.
  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.aws_auth_merger_namespace != null ? { enable = true } : {}

  name      = var.worker_k8s_role_mapping_name
  namespace = var.aws_auth_merger_namespace

  eks_worker_iam_role_arns = compact([
    module.self_managed_workers.eks_worker_iam_role_arn,
    module.managed_node_groups.eks_worker_iam_role_arn,
  ])

  config_map_labels = {
    eks-cluster = var.eks_cluster_name
  }
}
