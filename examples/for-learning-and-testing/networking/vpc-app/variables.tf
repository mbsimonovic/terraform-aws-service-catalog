variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cidr_block" {
  description = "The IP address range of the VPC in CIDR notation. A prefix of /18 is recommended. Do not use a prefix higher than /27. Examples include '10.100.0.0/18', '10.200.0.0/18', etc."
  type        = string
  default     = "10.0.0.0/16"
}

variable "num_nat_gateways" {
  description = "The number of NAT Gateways to launch for this VPC. For production VPCs, a NAT Gateway should be placed in each Availability Zone (so likely 3 total), whereas for non-prod VPCs, just one Availability Zone (and hence 1 NAT Gateway) will suffice."
  type        = string
  default     = 1
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "service-catalog-test"
}

variable "kms_key_id" {
  description = "The ID of a KMS key to use for encrypting VPC the flow log."
  type        = string
  default     = "alias/dedicated-test-key"
}
