# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all the resources created by the Memcached module. Must be unique in this region. Must be a lowercase string."
  type        = string
  default     = "memcached"
}

variable "aws_region" {
  description = "The AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}
