# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_version_tag" {
  description = "The version string of the AMI to run for the bastion host built from the template in modules/mgmt/bastion-host/bastion-host.json. This corresponds to the value passed in for version_tag in the Packer template."
  type        = string
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance."
  type        = string
}

variable "domain_name" {
  description = "The name of the domain in which to create a DNS record for the bastion host."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the bastion host."
  type        = string
  default     = "bastion-host"
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
