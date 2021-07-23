# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which to deploy the resources. This variable will be passed to the provider's region parameter."
  type        = string
  default     = "eu-west-1"
}

variable "domain_name" {
  description = "The name of the domain to provision."
  type        = string
  default     = "service-catalog-test.xyz"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "service-catalog-test"
}

variable "example_instance_keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the example instances cluster. Leave blank if you don't want to enable Key Pair auth"
  type        = string
  default     = null
}

variable "instance_types" {
  description = "A list of instance types to look up in the current AWS region."
  type        = list(string)
  default     = ["t3.micro", "t2.micro"]
}
