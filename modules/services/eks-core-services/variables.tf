# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster is deployed."
  type        = string
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster where the core services will be deployed into."
  type        = string
}

variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Set to null if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
}

# Fargate configuration

variable "worker_vpc_subnet_ids" {
  description = "The subnet IDs to use for EKS worker nodes. Used when provisioning Pods on to Fargate. Required if any of the services are being scheduled on Fargate. Set to empty list if none of the Pods are being scheduled on Fargate."
  type        = list(string)
}

variable "pod_execution_iam_role_arn" {
  description = "ARN of IAM Role to use as the Pod execution role for Fargate. Required if any of the services are being scheduled on Fargate. Set to null if none of the Pods are being scheduled on Fargate."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables have defaults and may be overwritten
# ---------------------------------------------------------------------------------------------------------------------

# Fluentd DaemonSet options

variable "fluentd_cloudwatch_pod_tolerations" {
  description = "Configure tolerations rules to allow the fluentd-cloudwatch Pods to schedule on nodes that have been tainted. Each item in the list specifies a toleration rule."
  type        = list(map(any))
  default     = []

  # Each item in the list represents a particular toleration. See
  # https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ for the various rules you can specify.
  #
  # Example:
  #
  # [
  #   {
  #     key = "node.kubernetes.io/unreachable"
  #     operator = "Exists"
  #     effect = "NoExecute"
  #     tolerationSeconds = 6000
  #   }
  # ]
}

variable "fluentd_cloudwatch_pod_node_affinity" {
  description = "Configure affinity rules for the fluentd-cloudwatch Pods to control which nodes to schedule on. Each item in the list should be a map with the keys `key`, `values`, and `operator`, corresponding to the 3 properties of matchExpressions. Note that all expressions must be satisfied to schedule on the node."
  type = list(object({
    key      = string
    values   = list(string)
    operator = string
  }))
  default = []

  # Each item in the list represents a matchExpression for requiredDuringSchedulingIgnoredDuringExecution.
  # https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity for the various
  # configuration option.
  #
  # Example:
  #
  # [
  #   {
  #     "key" = "node-label-key"
  #     "values" = ["node-label-value", "another-node-label-value"]
  #     "operator" = "In"
  #   }
  # ]
  #
  # Translates to:
  #
  # nodeAffinity:
  #   requiredDuringSchedulingIgnoredDuringExecution:
  #     nodeSelectorTerms:
  #     - matchExpressions:
  #       - key: node-label-key
  #         operator: In
  #         values:
  #         - node-label-value
  #         - another-node-label-value
}

# AWS ALB Ingress controller options

variable "schedule_alb_ingress_controller_on_fargate" {
  description = "When true, the ALB ingress controller pods will be scheduled on Fargate."
  type        = bool
  default     = false
}

variable "alb_ingress_controller_pod_tolerations" {
  description = "Configure tolerations rules to allow the ALB Ingress Controller Pod to schedule on nodes that have been tainted. Each item in the list specifies a toleration rule."
  type        = list(map(any))
  default     = []

  # Each item in the list represents a particular toleration. See
  # https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ for the various rules you can specify.
  #
  # Example:
  #
  # [
  #   {
  #     key = "node.kubernetes.io/unreachable"
  #     operator = "Exists"
  #     effect = "NoExecute"
  #     tolerationSeconds = 6000
  #   }
  # ]
}

variable "alb_ingress_controller_pod_node_affinity" {
  description = "Configure affinity rules for the ALB Ingress Controller Pod to control which nodes to schedule on. Each item in the list should be a map with the keys `key`, `values`, and `operator`, corresponding to the 3 properties of matchExpressions. Note that all expressions must be satisfied to schedule on the node."
  type = list(object({
    key      = string
    values   = list(string)
    operator = string
  }))
  default = []

  # Each item in the list represents a matchExpression for requiredDuringSchedulingIgnoredDuringExecution.
  # https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity for the various
  # configuration option.
  #
  # Example:
  #
  # [
  #   {
  #     "key" = "node-label-key"
  #     "values" = ["node-label-value", "another-node-label-value"]
  #     "operator" = "In"
  #   }
  # ]
  #
  # Translates to:
  #
  # nodeAffinity:
  #   requiredDuringSchedulingIgnoredDuringExecution:
  #     nodeSelectorTerms:
  #     - matchExpressions:
  #       - key: node-label-key
  #         operator: In
  #         values:
  #         - node-label-value
  #         - another-node-label-value
}

# external-dns configuration options

variable "schedule_external_dns_on_fargate" {
  description = "When true, the external-dns pods will be scheduled on Fargate."
  type        = bool
  default     = false
}

variable "external_dns_pod_tolerations" {
  description = "Configure tolerations rules to allow the external-dns Pod to schedule on nodes that have been tainted. Each item in the list specifies a toleration rule."
  type        = list(map(any))
  default     = []

  # Each item in the list represents a particular toleration. See
  # https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ for the various rules you can specify.
  #
  # Example:
  #
  # [
  #   {
  #     key = "node.kubernetes.io/unreachable"
  #     operator = "Exists"
  #     effect = "NoExecute"
  #     tolerationSeconds = 6000
  #   }
  # ]
}

variable "external_dns_pod_node_affinity" {
  description = "Configure affinity rules for the external-dns Pod to control which nodes to schedule on. Each item in the list should be a map with the keys `key`, `values`, and `operator`, corresponding to the 3 properties of matchExpressions. Note that all expressions must be satisfied to schedule on the node."
  type = list(object({
    key      = string
    values   = list(string)
    operator = string
  }))
  default = []

  # Each item in the list represents a matchExpression for requiredDuringSchedulingIgnoredDuringExecution.
  # https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity for the various
  # configuration option.
  #
  # Example:
  #
  # [
  #   {
  #     "key" = "node-label-key"
  #     "values" = ["node-label-value", "another-node-label-value"]
  #     "operator" = "In"
  #   }
  # ]
  #
  # Translates to:
  #
  # nodeAffinity:
  #   requiredDuringSchedulingIgnoredDuringExecution:
  #     nodeSelectorTerms:
  #     - matchExpressions:
  #       - key: node-label-key
  #         operator: In
  #         values:
  #         - node-label-value
  #         - another-node-label-value
}

variable "route53_record_update_policy" {
  description = "Policy for how DNS records are sychronized between sources and providers (options: sync, upsert-only)."
  type        = string
  default     = "sync"
  # NOTE: external-dns is designed not to touch any records that it has not created, even in sync mode.
  # See https://github.com/kubernetes-incubator/external-dns/blob/master/docs/faq.md#im-afraid-you-will-mess-up-my-dns-records
}

variable "external_dns_route53_hosted_zone_id_filters" {
  description = "Only create records in hosted zones that match the provided IDs. Empty list (default) means match all zones. Zones must satisfy all three constraints (var.external_dns_route53_hosted_zone_tag_filters, var.external_dns_route53_hosted_zone_id_filters, and var.external_dns_route53_hosted_zone_domain_filters)."
  type        = list(string)
  default     = []
}

variable "external_dns_route53_hosted_zone_tag_filters" {
  description = "Only create records in hosted zones that match the provided tags. Each item in the list should specify tag key and tag value as a map. Empty list (default) means match all zones. Zones must satisfy all three constraints (var.external_dns_route53_hosted_zone_tag_filters, var.external_dns_route53_hosted_zone_id_filters, and var.external_dns_route53_hosted_zone_domain_filters)."
  type = list(object({
    key   = string
    value = string
  }))
  default = []

  # Example:
  # [
  #   {
  #     key = "Name"
  #     value = "current"
  #   }
  # ]
}

variable "external_dns_route53_hosted_zone_domain_filters" {
  description = "Only create records in hosted zones that match the provided domain names. Empty list (default) means match all zones. Zones must satisfy all three constraints (var.external_dns_route53_hosted_zone_tag_filters, var.external_dns_route53_hosted_zone_id_filters, and var.external_dns_route53_hosted_zone_domain_filters)."
  type        = list(string)
  default     = []
}

# Cluster Autoscaler settings

variable "schedule_cluster_autoscaler_on_fargate" {
  description = "When true, the cluster autoscaler pods will be scheduled on Fargate. It is recommended to run the cluster autoscaler on Fargate to avoid the autoscaler scaling down a node where it is running (and thus shutting itself down during a scale down event). However, since Fargate is only supported on a handful of regions, we don't default to true here."
  type        = bool
  default     = false
}

variable "cluster_autoscaler_pod_tolerations" {
  description = "Configure tolerations rules to allow the cluster-autoscaler Pod to schedule on nodes that have been tainted. Each item in the list specifies a toleration rule."
  type        = list(map(any))
  default     = []

  # Each item in the list represents a particular toleration. See
  # https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ for the various rules you can specify.
  #
  # Example:
  #
  # [
  #   {
  #     key = "node.kubernetes.io/unreachable"
  #     operator = "Exists"
  #     effect = "NoExecute"
  #     tolerationSeconds = 6000
  #   }
  # ]
}

variable "cluster_autoscaler_pod_node_affinity" {
  description = "Configure affinity rules for the cluster-autoscaler Pod to control which nodes to schedule on. Each item in the list should be a map with the keys `key`, `values`, and `operator`, corresponding to the 3 properties of matchExpressions. Note that all expressions must be satisfied to schedule on the node."
  type = list(object({
    key      = string
    values   = list(string)
    operator = string
  }))
  default = []

  # Each item in the list represents a matchExpression for requiredDuringSchedulingIgnoredDuringExecution.
  # https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity for the various
  # configuration option.
  #
  # Example:
  #
  # [
  #   {
  #     "key" = "node-label-key"
  #     "values" = ["node-label-value", "another-node-label-value"]
  #     "operator" = "In"
  #   }
  # ]
  #
  # Translates to:
  #
  # nodeAffinity:
  #   requiredDuringSchedulingIgnoredDuringExecution:
  #     nodeSelectorTerms:
  #     - matchExpressions:
  #       - key: node-label-key
  #         operator: In
  #         values:
  #         - node-label-value
  #         - another-node-label-value
}

# Scale down parameters for autoscaler. See
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#i-have-a-couple-of-nodes-with-low-utilization-but-they-are-not-scaled-down-why
# for more info on how to set these values.

variable "autoscaler_scale_down_unneeded_time" {
  description = "Minimum time to wait since the node became unused before the node is considered for scale down by the autoscaler."
  type        = string
  default     = "10m"
}

variable "autoscaler_down_delay_after_add" {
  description = "Minimum time to wait after a scale up event before any node is considered for scale down."
  type        = string
  default     = "10m"
}