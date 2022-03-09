# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE WORKER GROUPS FOR EKS
# These templates create self-managed and/or managed worker groups for EKS to run containers for Kubernetes.
# The templates are broken up as follows:
# - main.tf                : EC2 baseline and computations to simplify logic.
# - self_managed.tf        : Resources for configuring self managed worker groups.
# - managed_node_groups.tf : Resources for configuring managed node groups.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0, < 4.0"
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
# Note that there are three calls: one for configuring common metrics (e.g., ASG alarms), one for self managed workers,
# and the other for managed node groups.
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline_common" {
  source = "../../base/ec2-baseline"

  name = join(
    "-",
    compact([var.eks_cluster_name, var.worker_name_prefix]),
  )

  enable_asg_cloudwatch_alarms = true
  asg_names                    = local.worker_asg_names
  num_asg_names                = length(var.autoscaling_group_configurations) + length(var.managed_node_group_configurations)
  alarms_sns_topic_arn         = var.alarms_sns_topic_arn

  ami         = var.cluster_instance_ami
  ami_filters = var.cluster_instance_ami_filters

  # Disable everything else
  enable_ssh_grunt                  = false
  enable_cloudwatch_log_aggregation = false
  enable_cloudwatch_metrics         = false
  should_render_cloud_init          = false

  # Backward compatibility feature flag
  use_managed_iam_policies = var.use_managed_iam_policies
}

module "ec2_baseline_asg" {
  count  = local.has_self_managed_workers ? 1 : 0
  source = "../../base/ec2-baseline"

  name = join(
    "-",
    compact([var.eks_cluster_name, var.worker_name_prefix, "asg"]),
  )
  iam_role_name = module.self_managed_workers.eks_worker_iam_role_name

  enable_ssh_grunt                    = local.enable_ssh_grunt
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn

  enable_cloudwatch_metrics = var.enable_cloudwatch_metrics

  # Disable everything else
  should_render_cloud_init          = false
  enable_cloudwatch_log_aggregation = false

  # Backward compatibility feature flag
  use_managed_iam_policies = var.use_managed_iam_policies
}

module "ec2_baseline_mng" {
  count  = local.has_managed_node_groups ? 1 : 0
  source = "../../base/ec2-baseline"

  name = join(
    "-",
    compact([var.eks_cluster_name, var.worker_name_prefix, "mng"]),
  )
  iam_role_name = module.managed_node_groups.eks_worker_iam_role_name

  enable_ssh_grunt                    = local.enable_ssh_grunt
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn

  enable_cloudwatch_metrics = var.enable_cloudwatch_metrics

  # Disable everything else
  should_render_cloud_init          = false
  enable_cloudwatch_log_aggregation = false

  # Backward compatibility feature flag
  use_managed_iam_policies = var.use_managed_iam_policies
}

locals {
  # Default context to use for configuring user data scripts.
  default_user_data_context = {
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

    # Extra args for bootstrap script
    use_prefix_mode_to_calculate_max_pods = var.use_prefix_mode_to_calculate_max_pods
    eks_kubelet_extra_args                = ""
    eks_bootstrap_script_options          = ""
    max_pods_allowed                      = null
  }

  # Trim excess whitespace, because AWS will do that on deploy. This prevents
  # constant redeployment because the userdata hash doesn't match the trimmed
  # userdata hash.
  # See: https://github.com/hashicorp/terraform-provider-aws/issues/5011#issuecomment-878542063
  default_user_data = trimspace(templatefile("${path.module}/user-data.sh", local.default_user_data_context))
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.50.1"

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
