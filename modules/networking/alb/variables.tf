# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "alb_name" {
  description = "The name of the ALB."
  type        = string

  validation {
    condition     = length(var.alb_name) <= 32
    error_message = "Your alb_name must be 32 characters or less in length."
  }
}

variable "is_internal_alb" {
  description = "If the ALB should only accept traffic from within the VPC, set this to true. If it should accept traffic from the public Internet, set it to false."
  type        = bool
}

variable "vpc_id" {
  description = "ID of the VPC where the ALB will be deployed"
  type        = string
}

variable "vpc_subnet_ids" {
  description = "The ids of the subnets that the ALB can use to source its IP"
  type        = list(string)
}

variable "num_days_after_which_archive_log_data" {
  description = "After this number of days, log files should be transitioned from S3 to Glacier. Enter 0 to never archive log data."
  type        = number
}

variable "num_days_after_which_delete_log_data" {
  description = "After this number of days, log files should be deleted from S3. Enter 0 to never delete log data."
  type        = number
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "ssl_policy" {
  description = "The AWS predefined TLS/SSL policy for the ALB. A List of policies can be found here: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies. AWS recommends ELBSecurityPolicy-2016-08 policy for general use but this policy includes TLSv1.0 which is rapidly being phased out. ELBSecurityPolicy-TLS-1-1-2017-01 is the next policy up that doesn't include TLSv1.0."
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB instance. If this is enabled, the load balancer cannot be deleted prior to disabling"
  type        = bool
  default     = false
}

variable "http_listener_ports" {
  description = "A list of ports for which an HTTP Listener should be created on the ALB. Tip: When you define Listener Rules for these Listeners, be sure that, for each Listener, at least one Listener Rule  uses the '*' path to ensure that every possible request path for that Listener is handled by a Listener Rule. Otherwise some requests won't route to any Target Group."
  type        = list(string)
  default     = []
}

variable "https_listener_ports_and_ssl_certs" {
  description = "A list of the ports for which an HTTPS Listener should be created on the ALB. Each item in the list should be a map with the keys 'port', the port number to listen on, and 'tls_arn', the Amazon Resource Name (ARN) of the SSL/TLS certificate to associate with the Listener to be created. If your certificate is issued by the Amazon Certificate Manager (ACM), specify var.https_listener_ports_and_acm_ssl_certs instead. Tip: When you define Listener Rules for these Listeners, be sure that, for each Listener, at least one Listener Rule  uses the '*' path to ensure that every possible request path for that Listener is handled by a Listener Rule. Otherwise some requests won't route to any Target Group."
  type = list(object({
    port    = number
    tls_arn = string
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     port    = 443
  #     tls_arn = "arn:aws:iam::123456789012:server-certificate/ProdServerCert"
  #   }
  # ]
}

variable "https_listener_ports_and_acm_ssl_certs" {
  description = "A list of the ports for which an HTTPS Listener should be created on the ALB. Each item in the list should be a map with the keys 'port', the port number to listen on, and 'tls_domain_name', the domain name of an SSL/TLS certificate issued by the Amazon Certificate Manager (ACM) to associate with the Listener to be created. If your certificate isn't issued by ACM, specify var.https_listener_ports_and_ssl_certs instead. Tip: When you define Listener Rules for these Listeners, be sure that, for each Listener, at least one Listener Rule  uses the '*' path to ensure that every possible request path for that Listener is handled by a Listener Rule. Otherwise some requests won't route to any Target Group."
  type = list(object({
    port            = number
    tls_domain_name = string
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     port            = 443
  #     tls_domain_name = "foo.your-company.com"
  #   }
  # ]
}

variable "allow_inbound_from_security_group_ids" {
  description = "The list of IDs of security groups that should have access to the ALB"
  type        = list(string)
  default     = []
}

variable "allow_inbound_from_cidr_blocks" {
  description = "The CIDR-formatted IP Address range from which this ALB will allow incoming requests. If var.is_internal_alb is false, use the default value. If var.is_internal_alb is true, consider setting this to the VPC's CIDR Block, or something even more restrictive."
  type        = list(string)
  default     = []
}

variable "access_logs_s3_bucket_name" {
  description = "The name to use for the S3 bucket where the ALB access logs will be stored. If you set this to null, a name will be generated automatically based on var.alb_name."
  type        = string
  default     = null
}

variable "should_create_access_logs_bucket" {
  description = "If true, create a new S3 bucket for access logs with the name in var.access_logs_s3_bucket_name. If false, assume the S3 bucket for access logs with the name in  var.access_logs_s3_bucket_name already exists, and don't create a new one. Note that if you set this to false, it's up to you to ensure that the S3 bucket has a bucket policy that grants Elastic Load Balancing permission to write the access logs to your bucket."
  type        = bool
  default     = true
}

variable "create_route53_entry" {
  description = "Set to true to create a Route 53 DNS A record for this ALB?"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "The ID of the hosted zone for the DNS A record to add for the ALB. Only used if var.create_route53_entry is true."
  type        = string
  default     = null
}

variable "domain_names" {
  description = "The list of domain names for the DNS A record to add for the ALB (e.g. alb.foo.com). Only used if var.create_route53_entry is true."
  type        = list(string)
  default     = []
}

variable "allow_all_outbound" {
  description = "Set to true to enable all outbound traffic on this ALB. If set to false, the ALB will allow no outbound traffic by default. This will make the ALB unusuable, so some other code must then update the ALB Security Group to enable outbound access!"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "The time in seconds that the client TCP connection to the ALB is allowed to be idle before the ALB closes the TCP connection."
  type        = number
  default     = 60
}

variable "drop_invalid_header_fields" {
  description = "If true, the ALB will drop invalid headers. Elastic Load Balancing requires that message header names contain only alphanumeric characters and hyphens."
  type        = bool
  default     = false
}

variable "custom_tags" {
  description = "A map of custom tags to apply to the ALB and its Security Group. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "default_action_content_type" {
  description = "If a request to the load balancer does not match any of your listener rules, the default action will return a fixed response with this content type."
  type        = string
  default     = "text/plain"
}

variable "default_action_body" {
  description = "If a request to the load balancer does not match any of your listener rules, the default action will return a fixed response with this body."
  type        = string
  default     = null
}

variable "default_action_status_code" {
  description = "If a request to the load balancer does not match any of your listener rules, the default action will return a fixed response with this status code."
  type        = number
  default     = 404
}

variable "acm_cert_statuses" {
  description = "When looking up the ACM certs passed in via https_listener_ports_and_acm_ssl_certs, only match certs with the given statuses. Valid values are PENDING_VALIDATION, ISSUED, INACTIVE, EXPIRED, VALIDATION_TIMED_OUT, REVOKED and FAILED."
  type        = list(string)
  default     = ["ISSUED"]
}

variable "acm_cert_types" {
  description = "When looking up the ACM certs passed in via https_listener_ports_and_acm_ssl_certs, only match certs of the given types. Valid values are AMAZON_ISSUED and IMPORTED."
  type        = list(string)
  default     = ["AMAZON_ISSUED", "IMPORTED"]
}

variable "force_destroy" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}
