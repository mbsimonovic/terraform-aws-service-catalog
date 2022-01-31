# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "eks_cluster_name" {
  description = "The name of the EKS cluster where the core services will be deployed into."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster is deployed."
  type        = string
}

variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Set to null if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
}

variable "pod_execution_iam_role_arn" {
  description = "ARN of IAM Role to use as the Pod execution role for Fargate. Required if any of the services are being scheduled on Fargate. Set to null if none of the Pods are being scheduled on Fargate."
  type        = string
}

variable "worker_vpc_subnet_ids" {
  description = "The subnet IDs to use for EKS worker nodes. Used when provisioning Pods on to Fargate. Required if any of the services are being scheduled on Fargate. Set to empty list of none of the Pods are being scheduled on Fargate."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
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

# Mappings for external domain names

variable "service_dns_mappings" {
  description = "Configure Kubernetes Services to lookup external DNS records. This can be useful to bind friendly internal service names to domains (e.g. map the service name 'rds' to the RDS database endpoint)."
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

variable "enable_fluent_bit" {
  description = "Whether or not to enable fluent-bit for log aggregation."
  type        = bool
  default     = true
}

variable "enable_fargate_fluent_bit" {
  description = "Whether or not to enable fluent-bit on EKS Fargate workers for log aggregation."
  type        = bool
  default     = true
}

variable "enable_aws_cloudwatch_agent" {
  description = "Whether to enable the AWS CloudWatch Agent DaemonSet for collecting container and node metrics from worker nodes (self-managed ASG or managed node groups)."
  type        = bool
  default     = true
}

variable "enable_alb_ingress_controller" {
  description = "Whether or not to enable the AWS LB Ingress controller."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Whether or not to enable external-dns for DNS entry syncing with Route 53 for Services and Ingresses."
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Whether or not to enable cluster-autoscaler for Autoscaling EKS worker nodes."
  type        = bool
  default     = true
}
