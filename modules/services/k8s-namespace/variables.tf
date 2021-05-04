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

variable "labels" {
  description = "Map of string key value pairs that can be used to organize and categorize the namespace and roles. See the Kubernetes Reference for more info (https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)."
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Map of string key default pairs that can be used to store arbitrary metadata on the namespace and roles. See the Kubernetes Reference for more info (https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)."
  type        = map(string)
  default     = {}
}

variable "full_access_rbac_entities" {
  description = "The list of RBAC entities that should have full access to the Namespace."
  type = list(object({
    # The type of entity. One of User, Group, or ServiceAccount
    kind = string

    # The name of the entity (e.g., the username or group name, depending on kind).
    name = string

    # The namespace where the entity is located. Only used for ServiceAccount.
    namespace = string
  }))
  default = []
}

variable "read_only_access_rbac_entities" {
  description = "The list of RBAC entities that should have read only access to the Namespace."
  type = list(object({
    # The type of entity. One of User, Group, or ServiceAccount
    kind = string

    # The name of the entity (e.g., the username or group name, depending on kind).
    name = string

    # The namespace where the entity is located. Only used for ServiceAccount.
    namespace = string
  }))
  default = []
}
