#---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
}

variable "namespace" {
  description = "The Kubernetes Namespace to deploy the application into."
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
  description = "The number of Pods to run on the Kubernetes cluster for this service."
  type        = number
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

# Pod container options

variable "desired_number_of_canary_pods" {
  description = "The number of canary Pods to run on the Kubernetes cluster for this service. If greater than 0, you must provide var.canary_image."
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
  description = "How the service will be exposed in the cluster. Must be one of `external` (accessible over the public Internet), `internal` (only accessible from within the same VPC as the cluster), `cluster-internal` (only accessible within the Kubernetes network)."
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

variable "ingress_annotations" {
  description = "A list of custom ingress annotations, such as health checks and TLS certificates, to add to the Helm chart. See: https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/ingress/annotation/"
  type        = map(string)
  default     = {}

  # Example:
  # {
  #   "alb.ingress.kubernetes.io/shield-advanced-protection" : "true"
  # }
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
  description = "Protocol (HTTP or HTTPS) that the liveness probe should use to connect to the application container."
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
  description = "Protocol (HTTP or HTTPS) that the readiness probe should use to connect to the application container."
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

## ALB health checks

variable "alb_health_check_protocol" {
  description = "Protocol (HTTP or HTTPS) that the ALB health check should use to connect to the application container."
  type        = string
  default     = "HTTP"
}

variable "alb_health_check_port" {
  description = "String value specifying the port that the ALB health check should probe. By default, this will be set to the traffic port."
  type        = string
  default     = "traffic-port"
}

variable "alb_health_check_path" {
  description = "URL path for the endpoint that the ALB health check should ping. Defaults to /."
  type        = string
  default     = "/"
}

variable "alb_health_check_interval" {
  description = "Interval between ALB health checks in seconds."
  type        = number
  default     = 30
}

variable "alb_health_check_timeout" {
  description = "The timeout, in seconds, during which no response from a target means a failed health check."
  type        = number
  default     = 10
}

variable "alb_health_check_healthy_threshold" {
  description = "The number of consecutive health check successes required before considering an unhealthy target healthy."
  type        = number
  default     = 2
}

variable "alb_health_check_success_codes" {
  description = "The HTTP status code that should be expected when doing health checks against the specified health check path. Accepts a single value (200), multiple values (200,201), or a range of values (200-300)."
  type        = string
  default     = "200"
}

## ALB ACM certificate

variable "alb_acm_certificate_arns" {
  description = "A list of ACM certificate ARNs to attach to the ALB. The first certificate in the list will be added as default certificate."
  type        = list(string)
  default     = []
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

# IAM role for IRSA

variable "iam_role_exists" {
  description = "Whether or not the IAM role passed in `iam_role_name` already exists. Set to true if it exists, or false if it needs to be created. Defaults to false."
  type        = bool
  default     = false
}

variable "iam_role_name" {
  description = "The name of an IAM role that will be used by the pod to access the AWS API. If `iam_role_exists` is set to false, this role will be created. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "The name of a service account to create for use with the pod. This service account will be mapped to the IAM role defined in `var.iam_role_name` to give the pod permissions to access the AWS API. Must be unique in this namespace. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type        = string
  default     = ""
}

variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
  default = {
    openid_connect_provider_arn = ""
    openid_connect_provider_url = ""
  }
}

variable "iam_policy" {
  description = "An object defining the policy to attach to `iam_role_name` if the IAM role is going to be created. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement. Ignored if `iam_role_arn` is provided. Leave as null if you do not wish to use IAM role with Service Accounts."
  type = map(object({
    resources = list(string)
    actions   = list(string)
    effect    = string
  }))
  default = null

  # Example:
  # iam_policy = {
  #   S3Access = {
  #     actions = ["s3:*"]
  #     resources = ["arn:aws:s3:::mybucket"]
  #     effect = "Allow"
  #   },
  #   SecretsManagerAccess = {
  #     actions = ["secretsmanager:GetSecretValue"],
  #     resources = ["arn:aws:secretsmanager:us-east-1:0123456789012:secret:mysecert"]
  #     effect = "Allow"
  #   }
  # }
}

# Debug options

variable "values_file_path" {
  description = "A local file path where the helm chart values will be emitted. Use to debug issues with the helm chart values. Set to null to prevent creation of the file."
  type        = string
  default     = null
}
