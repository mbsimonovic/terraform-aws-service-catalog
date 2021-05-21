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
  # renovate.json auto-update-variable: aws-sample-app
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

variable "ingress_path" {
  description = "Path prefix that should be matched to route to the service. Use /* to match all paths."
  type        = string
  default     = "/*"
}

variable "ingress_group" {
  description = "Assign the ingress resource to an IngressGroup. All Ingress rules of the group will be collapsed to a single ALB. The rules will be collapsed in priority order, with lower numbers being evaluated first."
  type = object({
    # Ingress group to assign to.
    name = string
    # The priority of the rules in this Ingress. Smaller numbers have higher priority.
    priority = number
  })
  default = null
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
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "The name of the context to use for authenticating to the Kubernetes cluster. Defaults to the configured default context in the kubeconfig file. Only used if var.kubeconfig_auth_type is `context`."
  type        = string
  default     = null
}

# Configurations for the sample app

variable "server_greeting" {
  description = "Greeting text that the sample app should return."
  type        = string
  default     = null
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
  description = "Kubernetes Secrets to be injected into the container. Each entry in the map represents a Secret to be injected, with the key representing the name of the Secret. The value is also a map, with each entry corresponding to an entry in the Secret, with the key corresponding to the Secret entry key and the value corresponding to the environment variable name. This allows you to inject secrets from a Secret resource without the secret value leaking into the config in plain text or into the terraform state."
  type        = map(map(string))
  default     = {}

  # Example: This will inject the foo key of the Secret mysecret as the environment variable MY_SECRET.
  # {
  #   mysecret = {
  #     foo = "MY_SECRET"
  #   }
  # }
}

variable "use_exec_plugin_for_auth" {
  description = "If this variable is set to true, and kubeconfig_auth_type is set to 'eks', then use an exec-based plugin to authenticate and fetch tokens for EKS. This is useful because EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy', and since the native Kubernetes provider in Terraform doesn't have a way to fetch up-to-date tokens, we recommend using an exec-based provider as a workaround. Use the use_kubergrunt_to_fetch_token input variable to control whether kubergrunt or aws is used to fetch tokens."
  type        = bool
  default     = true
}

variable "use_kubergrunt_to_fetch_token" {
  description = "EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To avoid this issue, we use an exec-based plugin to fetch an up-to-date token. If this variable is set to true, we'll use kubergrunt to fetch the token (in which case, kubergrunt must be installed and on PATH); if this variable is set to false, we'll use the aws CLI to fetch the token (in which case, aws must be installed and on PATH). Note this functionality is only enabled if use_exec_plugin_for_auth is set to true and kubeconfig_auth_type is set to 'eks'."
  type        = bool
  default     = true
}

variable "ingress_ssl_redirect_rule_already_exists" {
  description = "Set to true if the Ingress SSL redirect rule is managed externally. This is useful when configuring Ingress grouping and you only want one service to be managing the SSL redirect rules. Only used if ingress_configure_ssl_redirect is true."
  type        = bool
  default     = false
}

variable "ingress_access_logs_s3_bucket_already_exists" {
  description = "Set to true if the S3 bucket to store the Ingress access logs is managed external to this module."
  type        = bool
  default     = false
}

variable "ingress_access_logs_s3_bucket_name" {
  description = "The name to use for the S3 bucket where the Ingress access logs will be stored. If you leave this blank, a name will be generated automatically based on var.application_name."
  type        = string
  default     = null
}

variable "ingress_access_logs_s3_prefix" {
  description = "The prefix to use for ingress access logs associated with the ALB. All logs will be stored in a key with this prefix. If null, the application name will be used."
  type        = string
  default     = null
}
