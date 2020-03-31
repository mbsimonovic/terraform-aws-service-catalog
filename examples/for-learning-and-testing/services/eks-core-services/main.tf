# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY EKS CORE SERVICES
# - aws-alb-ingress-controller to convert Ingress resources into ALB
# - external-dns to translate Ingress hostnames to Route 53 records
# - cluster-autoscaler to autoscale self managed and managed workers based on Pod demand
# - fluentd-cloudwatch to ship container logs on workers to CloudWatch Logs
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "eks_core_services" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/eks-core-services?ref=v1.0.8"
  source = "../../../../modules/services/eks-core-services"

  aws_region                               = var.aws_region
  vpc_id                                   = var.vpc_id
  eks_cluster_name                         = var.eks_cluster_name
  eks_iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config
  worker_vpc_subnet_ids                    = var.worker_vpc_subnet_ids
  pod_execution_iam_role_arn               = var.pod_execution_iam_role_arn

  # To make testing easier, we will schedule everything we can on Fargate
  schedule_alb_ingress_controller_on_fargate = true
  schedule_external_dns_on_fargate           = true
  schedule_cluster_autoscaler_on_fargate     = true

  # external-dns config
  external_dns_route53_hosted_zone_id_filters     = var.external_dns_route53_hosted_zone_id_filters
  external_dns_route53_hosted_zone_tag_filters    = var.external_dns_route53_hosted_zone_tag_filters
  external_dns_route53_hosted_zone_domain_filters = var.external_dns_route53_hosted_zone_domain_filters

  # Cluster autoscaler settings. We set a short enough interval for testing purposes, but this should not be set too
  # short in production to avoid thrashing the cluster.
  # See https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#i-have-a-couple-of-nodes-with-low-utilization-but-they-are-not-scaled-down-why
  # for more info on how to set these values.
  autoscaler_scale_down_unneeded_time = "2m"
  autoscaler_down_delay_after_add     = "2m"
}
