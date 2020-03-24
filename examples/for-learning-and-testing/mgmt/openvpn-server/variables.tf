# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami" {
  description = "The ID of the AMI to run for the bastion host. Should be built from the Packer template in modules/mgmt/bastion-host/bastion-host.json."
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

variable "backup_bucket_name" {
  description = "The name of the S3 bucket that will be used to backup PKI secrets. This is a required variable because bucket names must be globally unique across all AWS customers."
  type        = string
}

variable "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS Key that will be used to encrypt/decrypt backup files."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the OpenVPN server."
  type        = string
  default     = "openvpn-server"
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
