# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "base_domain_name" {
  description = "The base domain (e.g., foo.com) in which to create a Route 53 A record for Jenkins. There must be a Route 53 Hosted Zone for this domain name."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "alb_subdomain" {
  description = "The subdomain of var.base_domain_name to create a DNS A record for ALB. E.g., If you set this to alb and var.base_domain_name to foo.com, this module will create an A record alb.foo.com."
  type        = string
  default     = "alb"
}

variable "alb_name" {
  description = "The name of the ALB. Do not include the environment name since this module will automatically append it to the value of this variable."
  type        = string
  default     = "public-alb"
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}



variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match var.base_domain_name."
  type        = map(string)
  default     = {}
}
