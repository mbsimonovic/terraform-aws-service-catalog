# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY CORE SYSTEM ADMINISTRATION SERVICES TO AN EKS CLUSTER
# - aws-alb-ingress-controller to convert Ingress resources into ALB
# - external-dns to translate Ingress hostnames to Route 53 records
# - cluster-autoscaler to autoscale self managed and managed workers based on Pod demand
# - fluentd-cloudwatch to ship container logs on workers to CloudWatch Logs
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.13.7 as the minimum version, as that version added support for module for_each, and includes the latest GPG key
  # for provider binary validation.
  required_version = ">= 0.13.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }

    # The underlying modules are only compatible with kubernetes provider 2.x
    kubernetes = {
      source = "hashicorp/kubernetes"
      # NOTE: 2.6.0 has a regression bug that prevents usage of the exec block with data source references, so we lock
      # to a version less than that. See https://github.com/hashicorp/terraform-provider-kubernetes/issues/1464 for more
      # details.
      version = "~> 2.0, < 2.6.0"
    }

    # The underlying modules are only compatible with helm provider 2.x
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE KUBERNETES AND HELM CONNECTION FOR EKS
# ---------------------------------------------------------------------------------------------------------------------

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
        ? ["eks", "token", "--cluster-id", var.eks_cluster_name]
        : ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
      )
    }
  }
}

provider "helm" {
  kubernetes {
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
          ? ["eks", "token", "--cluster-id", var.eks_cluster_name]
          : ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
        )
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP CLOUDWATCH LOGGING
# The following sets up and deploys fluent-bit to export the container logs to Cloudwatch. This is the recommended way to
# forward container logs from a Kubernetes deployment.
# ---------------------------------------------------------------------------------------------------------------------

module "aws_for_fluent_bit" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-container-logs?ref=v0.46.3"

  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.enable_fluent_bit ? { enable = true } : {}

  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  iam_role_name_prefix                 = var.eks_cluster_name
  extra_filters                        = var.fluent_bit_extra_filters
  extra_outputs                        = var.fluent_bit_extra_outputs
  cloudwatch_configuration = {
    region            = var.aws_region
    log_group_name    = local.maybe_log_group
    log_stream_prefix = var.fluent_bit_log_stream_prefix
  }
  pod_tolerations   = var.fluent_bit_pod_tolerations
  pod_node_affinity = var.fluent_bit_pod_node_affinity
}

module "fargate_fluent_bit" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-fargate-container-logs?ref=v0.46.3"

  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.enable_fargate_fluent_bit ? { enable = true } : {}

  fargate_execution_iam_role_arns = var.fargate_fluent_bit_execution_iam_role_arns
  extra_filters                   = var.fargate_fluent_bit_extra_filters
  extra_parsers                   = var.fargate_fluent_bit_extra_parsers
  cloudwatch_configuration = {
    region            = var.aws_region
    log_group_name    = local.maybe_log_group
    log_stream_prefix = var.fargate_fluent_bit_log_stream_prefix
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  count = local.create_cloudwatch_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.fluent_bit_log_group_retention
}

locals {
  create_cloudwatch_log_group = (var.enable_fluent_bit || var.enable_fargate_fluent_bit) && var.fluent_bit_log_group_already_exists == false
  log_group_name = (
    var.fluent_bit_log_group_name != null ? var.fluent_bit_log_group_name : var.eks_cluster_name
  )
  maybe_log_group = (
    length(aws_cloudwatch_log_group.eks_cluster) > 0
    ? aws_cloudwatch_log_group.eks_cluster[0].name
    : local.log_group_name
  )

  # The other core services depend on logging, so we create a local that captures this dependency relation.
  core_service_dependencies = [
    join("", aws_eks_fargate_profile.core_services.*.id),
    length(module.fargate_fluent_bit) > 0 ? module.fargate_fluent_bit["enable"].config_map_id : "",
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP AWS ALB INGRESS CONTROLLER
# The following sets up and deploys the AWS ALB Ingress Controller, which will translate Ingress resources into ALBs.
# ---------------------------------------------------------------------------------------------------------------------

module "alb_ingress_controller" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-alb-ingress-controller?ref=v0.46.3"

  # Ideally we would use module depends_on for this purpose, but module depends_on causes all data sources within the
  # module to be labeled as apply time data. This means that you end up with a perpetual diff. To avoid this, we use the
  # dependencies input to only apply the dependencies on the resources and not the data sources.
  dependencies = local.core_service_dependencies

  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.enable_alb_ingress_controller ? { enable = true } : {}

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-external-dns?ref=v0.46.3"

  # Ideally we would use module depends_on for this purpose, but module depends_on causes all data sources within the
  # module to be labeled as apply time data. This means that you end up with a perpetual diff. To avoid this, we use the
  # dependencies input to only apply the dependencies on the resources and not the data sources.
  dependencies = local.core_service_dependencies

  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.enable_external_dns ? { enable = true } : {}

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
  sources                            = var.external_dns_sources
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP K8S CLUSTER AUTOSCALER
# This deploys a cluster-autoscaler to the Kubernetes cluster which will monitor pod deployments and scale up
# worker nodes if pods ever fail to deploy due to resource constraints. The cluster-autoscaler is deployed in
# the core worker nodes (kube-system) but manages the Auto Scaling Groups for the application worker nodes.
# ---------------------------------------------------------------------------------------------------------------------

module "k8s_cluster_autoscaler" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-cluster-autoscaler?ref=v0.46.3"

  # Ideally we would use module depends_on for this purpose, but module depends_on causes all data sources within the
  # module to be labeled as apply time data. This means that you end up with a perpetual diff. To avoid this, we use the
  # dependencies input to only apply the dependencies on the resources and not the data sources.
  dependencies = local.core_service_dependencies

  # The contents of the for each set is irrelevant as it is only used to enable the module.
  for_each = var.enable_cluster_autoscaler ? { enable = true } : {}

  aws_region                           = var.aws_region
  eks_cluster_name                     = var.eks_cluster_name
  iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  pod_annotations                      = var.cluster_autoscaler_pod_annotations
  pod_labels                           = var.cluster_autoscaler_pod_labels
  pod_tolerations                      = var.cluster_autoscaler_pod_tolerations
  pod_node_affinity                    = var.cluster_autoscaler_pod_node_affinity
  pod_resources                        = var.cluster_autoscaler_pod_resources
  release_name                         = var.cluster_autoscaler_release_name

  cluster_autoscaler_version    = var.cluster_autoscaler_version
  cluster_autoscaler_repository = var.cluster_autoscaler_repository
  scaling_strategy              = var.cluster_autoscaler_scaling_strategy

  container_extra_args = {
    scale-down-unneeded-time      = var.autoscaler_scale_down_unneeded_time
    scale-down-delay-after-add    = var.autoscaler_down_delay_after_add
    skip-nodes-with-local-storage = var.autoscaler_skip_nodes_with_local_storage
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
  subnet_ids             = local.usable_fargate_subnet_ids

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
  should_create_fargate_profile = (
    (var.enable_alb_ingress_controller && var.schedule_alb_ingress_controller_on_fargate)
    || (var.enable_external_dns && var.schedule_external_dns_on_fargate)
    || (var.enable_cluster_autoscaler && var.schedule_cluster_autoscaler_on_fargate)
  )

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
          "app.kubernetes.io/name"     = "aws-load-balancer-controller"
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
