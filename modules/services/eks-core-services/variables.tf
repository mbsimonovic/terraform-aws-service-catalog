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

variable "fargate_worker_disallowed_availability_zones" {
  description = "A list of availability zones in the region that we CANNOT use to deploy the EKS Fargate workers. You can use this to avoid availability zones that may not be able to provision the resources (e.g ran out of capacity). If empty, will allow all availability zones."
  type        = list(string)
  default = [
    # The following zones are known to not support EKS Fargate.
    "us-east-1d",
    "us-east-1e",
  ]
}

# Fluent-bit DaemonSet options

variable "enable_fluent_bit" {
  description = "Whether or not to enable fluent-bit for log aggregation."
  type        = bool
  default     = true
}

variable "fluent_bit_log_group_name" {
  description = "Name of the CloudWatch Log Group fluent-bit should use to stream logs to. When null (default), uses the eks_cluster_name as the Log Group name."
  type        = string
  default     = null
}

variable "fluent_bit_log_group_already_exists" {
  description = "If set to true, that means that the CloudWatch Log Group fluent-bit should use for streaming logs already exists and does not need to be created."
  type        = bool
  default     = false
}

variable "fluent_bit_log_stream_prefix" {
  description = "Prefix string to use for the CloudWatch Log Stream that gets created for each pod. When null (default), the prefix is set to 'fluentbit'."
  type        = string
  default     = null
}

variable "fluent_bit_extra_filters" {
  description = "Additional filters that fluent-bit should apply to log output. This string should be formatted according to the Fluent-bit docs (https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/configuration-file#config_filter)."
  type        = string
  default     = ""
}

variable "fluent_bit_extra_outputs" {
  description = "Additional output streams that fluent-bit should export logs to. This string should be formatted according to the Fluent-bit docs (https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/configuration-file#config_output)."
  type        = string
  default     = ""
}

variable "fluent_bit_pod_tolerations" {
  description = "Configure tolerations rules to allow the fluent-bit Pods to schedule on nodes that have been tainted. Each item in the list specifies a toleration rule."
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

variable "fluent_bit_pod_node_affinity" {
  description = "Configure affinity rules for the fluent-bit Pods to control which nodes to schedule on. Each item in the list should be a map with the keys `key`, `values`, and `operator`, corresponding to the 3 properties of matchExpressions. Note that all expressions must be satisfied to schedule on the node."
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

variable "enable_alb_ingress_controller" {
  description = "Whether or not to enable the AWS LB Ingress controller."
  type        = bool
  default     = true
}

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

variable "enable_external_dns" {
  description = "Whether or not to enable external-dns for DNS entry syncing with Route 53 for Services and Ingresses."
  type        = bool
  default     = true
}

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

variable "external_dns_sources" {
  description = "K8s resources type to be observed for new DNS entries by ExternalDNS."
  type        = list(string)

  # NOTE ON ISTIO: By default, external-dns will listen for "ingress" and "service" events. To use it with Istio, make
  # sure to include the "istio-gateway" events here. See the docs for more details:
  # https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/istio.md
  default = ["ingress", "service"]
}

# Cluster Autoscaler settings

variable "enable_cluster_autoscaler" {
  description = "Whether or not to enable cluster-autoscaler for Autoscaling EKS worker nodes."
  type        = bool
  default     = true
}

variable "schedule_cluster_autoscaler_on_fargate" {
  description = "When true, the cluster autoscaler pods will be scheduled on Fargate. It is recommended to run the cluster autoscaler on Fargate to avoid the autoscaler scaling down a node where it is running (and thus shutting itself down during a scale down event). However, since Fargate is only supported on a handful of regions, we don't default to true here."
  type        = bool
  default     = false
}

variable "cluster_autoscaler_version" {
  description = "Which version of the cluster autoscaler to install. This should match the major/minor version (e.g., v1.20) of your Kubernetes Installation. See https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler#releases for a list of versions."
  type        = string
  default     = "v1.21.0"
}

variable "cluster_autoscaler_repository" {
  description = "Which docker repository to use to install the cluster autoscaler. Check the following link for valid repositories to use https://github.com/kubernetes/autoscaler/releases"
  type        = string
  default     = "us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler"
}

variable "cluster_autoscaler_scaling_strategy" {
  description = "Specifies an 'expander' for the cluster autoscaler. This helps determine which ASG to scale when additional resource capacity is needed."
  type        = string
  default     = "least-waste"
  # See https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-expanders
}

variable "cluster_autoscaler_pod_resources" {
  description = "Pod resource requests and limits to use. Refer to https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ for more information."

  # We use any type here to avoid maintaining the kubernetes defined type spec for the resources here. That way, we can
  # support wide range of kubernetes versions.
  type = any

  default = null
}

variable "cluster_autoscaler_pod_annotations" {
  description = "Annotations to apply to the cluster autoscaler pod(s), as key value pairs."
  type        = map(string)
  default     = {}
}

variable "cluster_autoscaler_pod_labels" {
  description = "Labels to apply to the cluster autoscaler pod(s), as key value pairs."
  type        = map(string)
  default     = {}
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

variable "cluster_autoscaler_release_name" {
  description = "The name to use for the helm release for cluster-autoscaler. This is useful to force a redeployment of the cluster-autoscaler component."
  type        = string
  default     = "cluster-autoscaler"
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

# Mappings for external domain names

variable "service_dns_mappings" {
  description = "Configure Kubernetes Services to lookup external DNS records. This can be useful to bind friendly internal service names to domains (e.g. the RDS database endpoint)."
  # Key is service name
  type = map(object({
    # DNS record to route requests to the Kubernetes Service to.
    target_dns = string

    # Port to route requests
    target_port = number

    # Namespace to create the underlying Kubernetes Service in.
    namespace = string
  }))

  default = {}
}

variable "use_exec_plugin_for_auth" {
  description = "If this variable is set to true, then use an exec-based plugin to authenticate and fetch tokens for EKS. This is useful because EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy', and since the native Kubernetes provider in Terraform doesn't have a way to fetch up-to-date tokens, we recommend using an exec-based provider as a workaround. Use the use_kubergrunt_to_fetch_token input variable to control whether kubergrunt or aws is used to fetch tokens."
  type        = bool
  default     = true
}

variable "use_kubergrunt_to_fetch_token" {
  description = "EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To avoid this issue, we use an exec-based plugin to fetch an up-to-date token. If this variable is set to true, we'll use kubergrunt to fetch the token (in which case, kubergrunt must be installed and on PATH); if this variable is set to false, we'll use the aws CLI to fetch the token (in which case, aws must be installed and on PATH). Note this functionality is only enabled if use_exec_plugin_for_auth is set to true."
  type        = bool
  default     = true
}
