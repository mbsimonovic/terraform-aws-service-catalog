# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC. Examples include 'prod', 'dev', 'mgmt', etc."
  type        = string
}

variable "cidr_block" {
  description = "The IP address range of the VPC in CIDR notation. A prefix of /18 is recommended. Do not use a prefix higher than /27. Examples include '10.100.0.0/18', '10.200.0.0/18', etc."
  type        = string
}

variable "num_nat_gateways" {
  description = "The number of NAT Gateways to launch for this VPC. For production VPCs, a NAT Gateway should be placed in each Availability Zone (so likely 3 total), whereas for non-prod VPCs, just one Availability Zone (and hence 1 NAT Gateway) will suffice."
  type        = number
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# The remaining variables are optional.
# ----------------------------------------------------------------------------------------------------------------------

variable "create_flow_logs" {
  description = "If you set this variable to false, this module will not create VPC Flow Logs resources. This is used as a workaround because Terraform does not allow you to use the 'count' parameter on modules. By using this parameter, you can optionally create or not create the resources within this module."
  type        = bool
  default     = true
}

variable "tenancy" {
  description = "The allowed tenancy of instances launched into the selected VPC. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "kms_key_user_iam_arns" {
  description = "VPC Flow Logs will be encrypted with a KMS Key (a Customer Master Key). The IAM Users specified in this list will have access to this key."
  type        = list(string)
  default     = null
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
}

variable "kms_key_arn" {
  description = "The ARN of a KMS key to use for encrypting VPC the flow log. A new KMS key will be created if this is not supplied."
  type        = string
  default     = null
}

variable "allow_private_persistence_internet_access" {
  description = "Should the private persistence subnet be allowed outbound access to the internet?"
  type        = bool
  default     = false
}

variable "tag_for_use_with_eks" {
  description = "The VPC resources need special tags for discoverability by Kubernetes to use with certain features, like deploying ALBs."
  type        = bool
  default     = false
}

variable "eks_cluster_names" {
  description = "The names of EKS clusters that will be deployed into the VPC, if var.tag_for_use_with_eks is true."
  type        = list(string)
  default     = []
}

variable "availability_zone_blacklisted_names" {
  description = "Specific Availability Zones in which subnets SHOULD NOT be created. Useful for when features / support is missing from a given AZ."
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS FOR VPC PEERING AND DNS FORWARDING
# ----------------------------------------------------------------------------------------------------------------------

variable "create_peering_connection" {
  description = "Whether or not to create a peering connection to another VPC."
  type        = bool
  default     = false
}

variable "create_dns_forwarder" {
  description = "Whether or not to create DNS forwarders from the Mgmt VPC to the App VPC to resolve private Route 53 endpoints. This is most useful when you want to keep your EKS Kubernetes API endpoint private to the VPC, but want to access it from the Mgmt VPC (where your VPN/Bastion servers are)."
  type        = bool
  default     = false
}

variable "origin_vpc_id" {
  description = "The ID of the origin VPC to use when creating peering connections and DNS forwarding."
  type        = string
  default     = null
}

variable "origin_vpc_name" {
  description = "The name of the origin VPC to use when creating peering connections and DNS forwarding."
  type        = string
  default     = null
}

variable "origin_vpc_route_table_ids" {
  description = "A list of route tables from the origin VPC that should have routes to this app VPC."
  type        = list(string)
  default     = []
}

variable "origin_vpc_cidr_block" {
  description = "The CIDR block of the origin VPC."
  type        = string
  default     = null
}

variable "origin_vpc_public_subnet_ids" {
  description = "The public subnets in the origin VPC to use when creating route53 resolvers. These are public subnets due to network ACLs restrictions. Although the forwarder is addressable publicly, access is blocked by security groups."
  type        = list(string)
  default     = null
}
