# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The ID of the AMI to run for the OpenVPN server. Should be built from the Packer template in modules/mgmt/openvpn-server.json."
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

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name in which to create the Route53 DNS record."
  type        = string
  default     = "gruntwork.in"
}

variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match var.domain_name."
  type        = map(string)
  default     = {}
}
