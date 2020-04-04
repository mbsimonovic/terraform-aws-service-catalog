# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
}

variable "image" {
  description = "The Docker image to run (e.g. gruntwork/frontend-service)"
  type        = string
}

variable "image_version" {
  description = "Which version (AKA tag) of the var.image Docker image to deploy (e.g. 0.57)"
  type        = string
}

variable "container_port" {
  description = "The port number on which this service's Docker container accepts incoming traffic."
  type        = number
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "namespace" {
  description = "Which Kubernetes Namespace to deploy the application into?"
  type        = string
  default     = "default"
}

variable "expose_type" {
  description = "How to expose the service? Must be one of `external` (publicly accessible outside of cluster), `internal` (internally accessible within VPC outside of cluster), `cluster-internal` (internally accessible only within Kubernetes)."
  type        = string
  default     = "cluster-internal"
}

variable "domain_name" {
  description = "The domain name for the DNS A record to add for this service (e.g. service.foo.com). Set to null to avoid creating the domain entry."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster lives. Only used when deploying against EKS (var.kubeconfig_auth_type = eks)."
  type        = string
  default     = "eu-west-1"
}

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
