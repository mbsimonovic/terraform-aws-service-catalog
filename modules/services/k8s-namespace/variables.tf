# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Name of the Namespace to create."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "schedule_pods_on_fargate" {
  description = "When true, will create a Fargate Profile that matches all Pods in the Namespace. This means that all Pods in the Namespace will be scheduled on Fargate. Note that this value is only used if var.kubeconfig_auth_type is eks, as Fargate profiles can only be created against EKS clusters."
  type        = bool
  default     = false
}

variable "pod_execution_iam_role_arn" {
  description = "ARN of IAM Role to use as the Pod execution role for Fargate. Required if var.schedule_pods_on_fargate is true."
  type        = string
  default     = null
}

variable "worker_vpc_subnet_ids" {
  description = "The subnet IDs to use for EKS worker nodes. Used when provisioning Pods on to Fargate. At least 1 subnet is required if var.schedule_pods_on_fargate is true."
  type        = list(string)
  default     = []
}

# Parameters for configuring how to authenticate to Kubernetes.

variable "kubeconfig_auth_type" {
  description = "Specifies how to authenticate to the Kubernetes cluster. Must be one of `eks`, `context`, or `service_account`. When `eks`, var.kubeconfig_eks_cluster_name is required. When `context`, configure the kubeconfig path and context name using var.kubeconfig_path and var.kubeconfig_context. `service_account` can only be used if this module is deployed from within a Kubernetes Pod."
  type        = string
  default     = "context"
}

variable "kubeconfig_eks_cluster_name" {
  description = "Name of the EKS cluster where the Namespace will be created. Required when var.kubeconfig_auth_type is `eks`."
  type        = string
  default     = null
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file containing authentication configurations for Kubernetes clusters. Defaults to ~/.kube/config. Only used if var.kubeconfig_auth_type is `context`."
  type        = string
  default     = null
}

variable "kubeconfig_context" {
  description = "The name of the context to use for authenticating to the Kubernetes cluster. Defaults to the configured default context in the kubeconfig file. Only used if var.kubeconfig_auth_type is `context`."
  type        = string
  default     = null
}
