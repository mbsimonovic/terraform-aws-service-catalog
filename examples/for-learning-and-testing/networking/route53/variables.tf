# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "internal_services_domain_name" {
  description = "The domain name to use for internal services (e.g., acme.aws)"
  type        = string
  default     = "acme.aws"
}

variable "vpc_id" {
  description = "The ID of the VPC in which to create the Route 53 Private Zone"
  type        = string
}

