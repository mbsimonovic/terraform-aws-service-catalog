# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "internal_services_domain_name" {
  description = "The domain name to use for internal services (e.g., acme.aws)"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC in which to create the Route 53 Private Hosted Zones"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to create the Route 53 Private Zone"
  type        = string
}

