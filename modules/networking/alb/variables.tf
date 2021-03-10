# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "alb_name" {
  description = "The name of the ALB."
  type        = string
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

variable "force_destroy" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}
