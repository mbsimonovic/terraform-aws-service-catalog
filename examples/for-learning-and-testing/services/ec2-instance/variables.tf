# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_version_tag" {
  description = "The version string of the AMI to run for the EC2 instance built from the template in modules/services/ec2-instance/ec2-instance.json. This corresponds to the value passed in for version_tag in the Packer template."
  type        = string
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the EC2 instance."
  type        = string
  default     = "ec2-instance"
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

variable "create_dns_record" {
  description = "Set to true to create a DNS record in Route53 pointing to the EC2 instance. If true, be sure to set var.domain_name."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The name of the domain in which to create a DNS record for the EC2 instance."
  type        = string
  default     = ""
}
