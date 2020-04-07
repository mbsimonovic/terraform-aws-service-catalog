#---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
}

variable "namespace" {
  description = "Which Kubernetes Namespace to deploy the application into?"
  type        = string
}

# Docker image configuration

variable "container_image" {
  description = "The Docker image to run."
  type = object({
    # Repository of the docker image (e.g. gruntwork/frontend-service)
    repository = string
    # The tag of the docker image to deploy.
    tag = string
    # The image pull policy. Can be one of IfNotPresent, Always, or Never.
    pull_policy = string
  })
}

variable "container_port" {
  description = "The port number on which this service's Docker container accepts incoming traffic."
  type        = number
}

variable "desired_number_of_pods" {
  description = "How many Pods to run on the Kubernetes cluster?"
  type        = number
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

# Pod container options

variable "desired_number_of_canary_pods" {
  description = "How many canary pods to run. If greater than 0, you must provide var.canary_image."
  type        = number
  default     = 0
}

variable "canary_image" {
  description = "The Docker image to use for the canary. Required if desired_number_of_canary_pods is greater than 0."
  type = object({
    # Repository of the docker image (e.g. gruntwork/frontend-service)
    repository = string
    # The tag of the docker image to deploy.
    tag = string
    # The image pull policy. Can be one of IfNotPresent, Always, or Never.
    pull_policy = string
  })
  default = null
}

variable "container_protocol" {
  description = "The protocol on which this service's Docker container accepts traffic. Must be one of the supported protocols: https://kubernetes.io/docs/concepts/services-networking/service/#protocol-support."
  type        = string
  default     = "TCP"
}

# Access point configuration. Used to configure Service and Ingress/ALB (if externally exposed to cluster)

variable "expose_type" {
  description = "How to expose the service? Must be one of `external` (publicly accessible outside of cluster), `internal` (internally accessible within VPC outside of cluster), `cluster-internal` (internally accessible only within Kubernetes)."
  type        = string
  default     = "cluster-internal"
}

variable "ingress_configure_ssl_redirect" {
  description = "When true, HTTP requests will automatically be redirected to use SSL (HTTPS). Used only when expose_type is either external or internal."
  type        = bool
  default     = true
}

variable "ingress_listener_protocol_ports" {
  description = "A list of maps of protocols and ports that the ALB should listen on."
  type = list(object({
    protocol = string
    port     = number
  }))
  default = [
    {
      protocol = "HTTP"
      port     = 80
    },
    {
      protocol = "HTTPS"
      port     = 443
    },
  ]
}

variable "ingress_path" {
  description = "Path prefix that should be matched to route to the service. Use / to match all paths."
  type        = string
  default     = "/"
}

variable "ingress_backend_protocol" {
  description = "The protocol used by the Ingress ALB resource to communicate with the Service. Must be one of HTTP or HTTPS."
  type        = string
  default     = "HTTP"
}

variable "service_port" {
  description = "The port to expose on the Service. This is most useful when addressing the Service internally to the cluster, as it is ignored when connecting from the Ingress resource."
  type        = number
  default     = 80
}

variable "force_destroy_ingress_access_logs" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}

variable "ingress_access_logs_s3_bucket_name" {
  description = "The name to use for the S3 bucket where the Ingress access logs will be stored. If you leave this blank, a name will be generated automatically based on var.application_name."
  type        = string
  default     = ""
}

variable "num_days_after_which_archive_ingress_log_data" {
  description = "After this number of days, Ingress log files should be transitioned from S3 to Glacier. Set to 0 to never archive logs."
  type        = number
  default     = 0
}

variable "num_days_after_which_delete_ingress_log_data" {
  description = "After this number of days, Ingress log files should be deleted from S3. Set to 0 to never delete logs."
  type        = number
  default     = 0
}

# Route 53 / DNS Info

variable "create_route53_entry" {
  description = "Set to true to create a Route 53 entry for this service"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name for the DNS A record to add for this service (e.g. service.foo.com). Only used if var.create_route53_entry is true."
  type        = string
  default     = ""
}

# Healthcheck options

## Liveness Config

variable "enable_liveness_probe" {
  description = "Whether or not to enable liveness probe. Liveness checks indicate whether or not the container is alive. When these checks fail, the cluster will automatically rotate the Pod."
  type        = bool
  default     = false
}

variable "liveness_probe_port" {
  description = "Port that the liveness probe should use to connect to the application container."
  type        = number
  default     = 80
}

variable "liveness_probe_protocol" {
  description = "Protocol (HTTP or HTTPS) that the liveness probe should use to connect to the application contianer."
  type        = string
  default     = "HTTP"
}

variable "liveness_probe_path" {
  description = "URL path for the endpoint that the liveness probe should ping."
  type        = string
  default     = "/"
}

variable "liveness_probe_grace_period_seconds" {
  description = "Seconds to wait after Pod creation before liveness probe has any effect. Any failures during this period are ignored."
  type        = number
  default     = 15
}

variable "liveness_probe_interval_seconds" {
  description = "The approximate amount of time, in seconds, between liveness checks of an individual Target."
  type        = number
  default     = 30
}

## Readiness Config

variable "enable_readiness_probe" {
  description = "Whether or not to enable readiness probe. Readiness checks indicate whether or not the container can accept traffic. When these checks fail, the Pods are automatically removed from the Service (and added back in when they pass)."
  type        = bool
  default     = false
}

variable "readiness_probe_port" {
  description = "Port that the readiness probe should use to connect to the application container."
  type        = number
  default     = 80
}

variable "readiness_probe_protocol" {
  description = "Protocol (HTTP or HTTPS) that the readiness probe should use to connect to the application contianer."
  type        = string
  default     = "HTTP"
}

variable "readiness_probe_path" {
  description = "URL path for the endpoint that the readiness probe should ping."
  type        = string
  default     = "/"
}

variable "readiness_probe_grace_period_seconds" {
  description = "Seconds to wait after Pod creation before liveness probe has any effect. Any failures during this period are ignored."
  type        = number
  default     = 15
}

variable "readiness_probe_interval_seconds" {
  description = "The approximate amount of time, in seconds, between liveness checks of an individual Target."
  type        = number
  default     = 30
}

# Docker options

variable "env_vars" {
  description = "A map of environment variable name to environment variable value that should be made available to the Docker container."
  type        = map(string)
  default     = {}
}

variable "configmaps_as_volumes" {
  description = "Kubernetes ConfigMaps to be injected into the container as volume mounts. Each entry in the map represents a ConfigMap to be mounted, with the key representing the name of the ConfigMap and the value representing a file path on the container to mount the ConfigMap to."
  type        = map(string)
  default     = {}

  # Example: This will mount the ConfigMap myconfig to the path /etc/myconfig
  # {
  #   myconfig = "/etc/myconfig"
  # }
}

variable "configmaps_as_env_vars" {
  description = "Kubernetes ConfigMaps to be injected into the container. Each entry in the map represents a ConfigMap to be injected, with the key representing the name of the ConfigMap. The value is also a map, with each entry corresponding to an entry in the ConfigMap, with the key corresponding to the ConfigMap entry key and the value corresponding to the environment variable name."
  type        = map(string)
  default     = {}

  # Example: This will inject the foo key of the ConfigMap myconfig as the environment variable MY_CONFIG.
  # {
  #   myconfig = {
  #     foo = "MY_CONFIG"
  #   }
  # }
}

variable "secrets_as_volumes" {
  description = "Kubernetes Secrets to be injected into the container as volume mounts. Each entry in the map represents a Secret to be mounted, with the key representing the name of the Secret and the value representing a file path on the container to mount the Secret to."
  type        = map(string)
  default     = {}

  # Example: This will mount the Secret mysecret to the path /etc/mysecret
  # {
  #   mysecret = "/etc/mysecret"
  # }
}

variable "secrets_as_env_vars" {
  description = "Kubernetes Secrets to be injected into the container. Each entry in the map represents a Secret to be injected, with the key representing the name of the Secret. The value is also a map, with each entry corresponding to an entry in the Secret, with the key corresponding to the Secret entry key and the value corresponding to the environment variable name."
  type        = map(string)
  default     = {}

  # Example: This will inject the foo key of the Secret mysecret as the environment variable MY_SECRET.
  # {
  #   mysecret = {
  #     foo = "MY_SECRET"
  #   }
  # }
}

# Debug options

variable "values_file_path" {
  description = "A local file path where the helm chart values will be emitted. Use to debug issues with the helm chart values. Set to null to prevent creation of the file."
  type        = string
  default     = null
}
