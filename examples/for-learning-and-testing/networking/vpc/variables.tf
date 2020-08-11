# ----------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# There are no required variables, all of them are optional.
# ----------------------------------------------------------------------------------------------------------------------

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

variable "sg_ingress_port" {
  description = "A port number to allow in the security group used by the example EC2 instance."
  type        = number
  default     = 8080
}

variable "kms_key_id" {
  description = "The ID of a KMS key to use for encrypting VPC the flow log."
  type        = string
  default     = "alias/dedicated-test-key"
}

variable "create_flow_logs" {
  description = "If you set this variable to false, this module will not create VPC Flow Logs resources. This is used as a workaround because Terraform does not allow you to use the 'count' parameter on modules. By using this parameter, you can optionally create or not create the resources within this module."
  type        = bool
  default     = false
}

variable "instance_types" {
  description = "A list of instance types to look up in the current AWS region."
  type        = list(string)
  default     = ["t3.micro", "t2.micro"]
}
