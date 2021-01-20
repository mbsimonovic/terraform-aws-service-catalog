# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY CORE SYSTEM ADMINISTRATION SERVICES TO AN EKS CLUSTER
# - aws-alb-ingress-controller to convert Ingress resources into ALB
# - external-dns to translate Ingress hostnames to Route 53 records
# - cluster-autoscaler to autoscale self managed and managed workers based on Pod demand
# - fluentd-cloudwatch to ship container logs on workers to CloudWatch Logs
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
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

    # This module uses Helm 3, which depends on helm provider version 1.x series.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 1.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE KUBERNETES AND HELM CONNECTION FOR EKS
# ---------------------------------------------------------------------------------------------------------------------

provider "kubernetes" {
  load_config_file       = false
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.kubernetes_token.token
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP CLOUDWATCH LOGGING
# The following sets up and deploys fluentd to export the container logs to Cloudwatch. This is the recommended way to
# forward container logs from a Kubernetes deployment.
# ---------------------------------------------------------------------------------------------------------------------

module "aws_for_fluent_bit" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-container-logs?ref=v0.32.0"

  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  iam_role_name_prefix                 = var.eks_cluster_name
  cloudwatch_configuration = {
    region            = var.aws_region
    log_group_name    = local.maybe_log_group
    log_stream_prefix = var.fluent_bit_log_stream_prefix
  }
  pod_tolerations   = var.fluent_bit_pod_tolerations
  pod_node_affinity = var.fluent_bit_pod_node_affinity
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  count = var.fluent_bit_log_group_already_exists == false ? 1 : 0
  name  = local.log_group_name
}

locals {
  log_group_name = (
    var.fluent_bit_log_group_name != null ? var.fluent_bit_log_group_name : var.eks_cluster_name
  )
  maybe_log_group = (
    var.fluent_bit_log_group_already_exists ? local.log_group_name : aws_cloudwatch_log_group.eks_cluster[0].name
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP AWS ALB INGRESS CONTROLLER
# The following sets up and deploys the AWS ALB Ingress Controller, which will translate Ingress resources into ALBs.
# ---------------------------------------------------------------------------------------------------------------------

module "alb_ingress_controller" {
  source       = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-alb-ingress-controller?ref=v0.32.0"
  dependencies = aws_eks_fargate_profile.core_services.*.id

  aws_region                           = var.aws_region
  eks_cluster_name                     = var.eks_cluster_name
  vpc_id                               = var.vpc_id
  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  pod_tolerations                      = var.alb_ingress_controller_pod_tolerations
  pod_node_affinity                    = var.alb_ingress_controller_pod_node_affinity
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP K8S EXTERNAL DNS
# The following sets up and deploys the external-dns Kubernetes app, which will create the necessary DNS records in
# Route 53 for the host paths specified on Ingress resources.
# ---------------------------------------------------------------------------------------------------------------------

module "k8s_external_dns" {
  source       = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-external-dns?ref=v0.32.0"
  dependencies = aws_eks_fargate_profile.core_services.*.id

  aws_region                           = var.aws_region
  eks_cluster_name                     = var.eks_cluster_name
  txt_owner_id                         = var.eks_cluster_name
  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  pod_tolerations                      = var.external_dns_pod_tolerations
  pod_node_affinity                    = var.external_dns_pod_node_affinity

  route53_record_update_policy       = var.route53_record_update_policy
  route53_hosted_zone_id_filters     = var.external_dns_route53_hosted_zone_id_filters
  route53_hosted_zone_tag_filters    = var.external_dns_route53_hosted_zone_tag_filters
  route53_hosted_zone_domain_filters = var.external_dns_route53_hosted_zone_domain_filters
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP K8S CLUSTER AUTOSCALER
# This deploys a cluster-autoscaler to the Kubernetes cluster which will monitor pod deployments and scale up
# worker nodes if pods ever fail to deploy due to resource constraints. The cluster-autoscaler is deployed in
# the core worker nodes (kube-system) but manages the Auto Scaling Groups for the application worker nodes.
# ---------------------------------------------------------------------------------------------------------------------

module "k8s_cluster_autoscaler" {
  source       = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-cluster-autoscaler?ref=v0.32.0"
  dependencies = aws_eks_fargate_profile.core_services.*.id

  aws_region                           = var.aws_region
  eks_cluster_name                     = var.eks_cluster_name
  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  pod_tolerations                      = var.cluster_autoscaler_pod_tolerations
  pod_node_affinity                    = var.cluster_autoscaler_pod_node_affinity

  container_extra_args = {
    scale-down-unneeded-time   = var.autoscaler_scale_down_unneeded_time
    scale-down-delay-after-add = var.autoscaler_down_delay_after_add
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# MANAGE FARGATE PROFILES
# Instead of relying on each module to configure the fargate profile, we will create a single fargate profile that will
# account for all the Pods deployed. The main reason for this approach is to optimize around an AWS limitation where you
# can only manage Fargate Profiles one at a time. That is, you can not create another Fargate Profile while one is being
# provisioned.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_eks_fargate_profile" "core_services" {
  count                  = local.should_create_fargate_profile ? 1 : 0
  cluster_name           = var.eks_cluster_name
  fargate_profile_name   = "core-services"
  pod_execution_role_arn = var.pod_execution_iam_role_arn
  subnet_ids             = var.worker_vpc_subnet_ids

  dynamic "selector" {
    for_each = local.fargate_profile_selectors
    content {
      namespace = local.namespace
      labels    = selector.value
    }
  }

  # Fargate Profiles can take a long time to delete if there are Pods, since the nodes need to deprovision.
  timeouts {
    delete = "1h"
  }
}

locals {
  should_create_fargate_profile = var.schedule_alb_ingress_controller_on_fargate || var.schedule_external_dns_on_fargate || var.schedule_cluster_autoscaler_on_fargate

  # Create a map of all the labels for the fargate profile selectors we need to create in the profile. We use a merge
  # with a conditional expression to conditionally add each entry into the map for for_each purposes.
  # NOTE: The fluentd cloudwatch service is intentionally not included in this logic because DaemonSets can not be
  # scheduled on Fargate.
  # MAINTAINER'S NOTE: Fargate profiles have a limit of 5 selectors. We will need to break this up into multiple
  # profiles when we have more than 5 core services that are compatible with Fargate.
  namespace = "kube-system"
  fargate_profile_selectors = merge(
    (
      var.schedule_alb_ingress_controller_on_fargate
      ? {
        aws-alb-ingress-controller = {
          "app.kubernetes.io/name"     = "aws-alb-ingress-controller"
          "app.kubernetes.io/instance" = "aws-alb-ingress-controller"
        }
      }
      : {}
    ),
    (
      var.schedule_external_dns_on_fargate
      ? {
        external-dns = {
          "app.kubernetes.io/name"     = "external-dns"
          "app.kubernetes.io/instance" = "external-dns"
        }
      }
      : {}
    ),
    (
      var.schedule_cluster_autoscaler_on_fargate
      ? {
        cluster-autoscaler = {
          "app.kubernetes.io/name"     = "aws-cluster-autoscaler"
          "app.kubernetes.io/instance" = "cluster-autoscaler"
        }
      }
      : {}
    ),
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP KUBERNETES SERVICE FOR SERVICE DISCOVERY
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_service" "mapping" {
  for_each = var.service_dns_mappings

  metadata {
    name      = each.key
    namespace = each.value.namespace
  }

  spec {
    type          = "ExternalName"
    external_name = each.value.target_dns

    port {
      port = each.value.target_port
    }
  }
}
