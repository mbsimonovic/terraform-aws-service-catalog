# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
  default     = "sample-app"
}

variable "container_port" {
  description = "The port number on which this service's Docker container accepts incoming traffic."
  type        = number
  default     = 8080
}

variable "image" {
  description = "The Docker image to run (e.g. gruntwork/frontend-service). This example is configured to deploy the Gruntwork AWS Sample App (https://github.com/gruntwork-io/aws-sample-app/), a node.js based app that demonstrates best practices and patterns for production. Refer to the comments in main.tf for how to adapt this example to deploy other kinds of apps."
  type        = string
  default     = "gruntwork/aws-sample-app"
}

variable "image_version" {
  description = "Which version (AKA tag) of the var.image Docker image to deploy (e.g. 0.57)."
  type        = string
  # renovate.json auto-update-github-releases: gruntwork-io/aws-sample-app
  default = "v0.0.2"
}

variable "namespace" {
  description = "The Kubernetes Namespace to deploy the application into."
  type        = string
  default     = "default"
}

variable "expose_type" {
  description = "How the service will be exposed in the cluster. Must be one of `external` (accessible over the public Internet), `internal` (only accessible from within the same VPC as the cluster), `cluster-internal` (only accessible within the Kubernetes network)."
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

# Configurations for the sample app

variable "app_environment_name" {
  description = "The environment name for the app: e.g., development, test, dev, stage, prod. From this variable, we will derive NODE_ENV, which will always be set to development, test, or production."
  type        = string
  default     = "dev"
}

variable "configmaps_as_env_vars" {
  description = "Kubernetes ConfigMaps to be injected into the container. Each entry in the map represents a ConfigMap to be injected, with the key representing the name of the ConfigMap. The value is also a map, with each entry corresponding to an entry in the ConfigMap, with the key corresponding to the ConfigMap entry key and the value corresponding to the environment variable name."
  type        = map(map(string))
  default     = {}

  # Example: This will inject the foo key of the ConfigMap myconfig as the environment variable MY_CONFIG.
  # {
  #   myconfig = {
  #     foo = "MY_CONFIG"
  #   }
  # }
}

variable "secrets_as_env_vars" {
  description = "Kubernetes Secrets to be injected into the container. Each entry in the map represents a Secret to be injected, with the key representing the name of the Secret. The value is also a map, with each entry corresponding to an entry in the Secret, with the key corresponding to the Secret entry key and the value corresponding to the environment variable name."
  type        = map(map(string))
  default     = {}

  # Example: This will inject the foo key of the Secret mysecret as the environment variable MY_SECRET.
  # {
  #   mysecret = {
  #     foo = "MY_SECRET"
  #   }
  # }
}
