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

variable "eks_cluster_name" {
  description = "Name of the EKS cluster where the Namespace will be created. Required when var.schedule_pods_on_fargate is `true`."
  type        = string
  default     = null
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
