# ---------------------------------------------------------------------------------------------------------------------
# VPC PARAMETERS
# This is the VPC to use for management tasks in this account, such as building AMIs with Packer, running CI servers
# such as Jenkins, and running infra CI tools such as the ecs-deploy-runner. It's a good practice to isolate all these
# management tasks from your production workloads at the network layer, so we create a dedicated VPC.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC. Defaults to mgmt."
  type        = string
}

variable "cidr_block" {
  description = "The IP address range of the VPC in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27. Examples include '10.100.0.0/16', '10.200.0.0/16', etc."
  type        = string
}

variable "num_nat_gateways" {
  description = "The number of NAT Gateways to launch for this VPC. The management VPC defaults to 1 NAT Gateway to save on cost, but to increase redundancy, you can adjust this to add additional NAT Gateways."
  type        = number
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# The remaining variables are optional.
# ----------------------------------------------------------------------------------------------------------------------

variable "num_availability_zones" {
  description = "How many AWS Availability Zones (AZs) to use. One subnet of each type (public, private app) will be created in each AZ. Note that this must be less than or equal to the total number of AZs in a region. A value of null means all AZs should be used. For example, if you specify 3 in a region with 5 AZs, subnets will be created in just 3 AZs instead of all 5. Defaults to 3."
  type        = number
  default     = null
}

variable "availability_zone_exclude_names" {
  description = "List of excluded Availability Zone names."
  type        = list(string)
  default     = []
}

variable "availability_zone_exclude_ids" {
  description = "List of excluded Availability Zone IDs."
  type        = list(string)
  default     = []
}

variable "availability_zone_state" {
  description = "Allows to filter list of Availability Zones based on their current state. Can be either \"available\", \"information\", \"impaired\" or \"unavailable\". By default the list includes a complete set of Availability Zones to which the underlying AWS account has access, regardless of their state."
  type        = string
  default     = null
}

variable "public_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 4
}

variable "private_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 4
}

variable "subnet_spacing" {
  description = "The amount of spacing between the different subnet types"
  type        = number
  default     = 8
}

variable "public_subnet_cidr_blocks" {
  description = "A map listing the specific CIDR blocks desired for each public subnet. The key must be in the form AZ-0, AZ-1, ... AZ-n where n is the number of Availability Zones. If left blank, we will compute a reasonable CIDR block for each subnet."
  type        = map(string)
  default     = {}
  # Example:
  # default = {
  #    AZ-0 = "10.226.20.0/24"
  #    AZ-1 = "10.226.21.0/24"
  #    AZ-2 = "10.226.22.0/24"
  # }
}

variable "private_subnet_cidr_blocks" {
  description = "A map listing the specific CIDR blocks desired for each private subnet. The key must be in the form AZ-0, AZ-1, ... AZ-n where n is the number of Availability Zones. If left blank, we will compute a reasonable CIDR block for each subnet."
  type        = map(string)
  default     = {}
  # Example:
  # default = {
  #    AZ-0 = "10.226.30.0/24"
  #    AZ-1 = "10.226.31.0/24"
  #    AZ-2 = "10.226.32.0/24"
  # }
}

variable "custom_tags" {
  description = "A map of tags to apply to the VPC, Subnets, Route Tables, and Internet Gateway. The key is the tag name and the value is the tag value. Note that the tag 'Name' is automatically added by this module but may be optionally overwritten by this variable."
  type        = map(string)
  default     = {}
}

variable "custom_tags_vpc_only" {
  description = "A map of tags to apply just to the VPC itself, but not any of the other resources. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "public_subnet_custom_tags" {
  description = "A map of tags to apply to the public Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "private_subnet_custom_tags" {
  description = "A map of tags to apply to the private Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "nat_gateway_custom_tags" {
  description = "A map of tags to apply to the NAT gateways, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "create_flow_logs" {
  description = "If you set this variable to false, this module will not create VPC Flow Logs resources. This is used as a workaround because Terraform does not allow you to use the 'count' parameter on modules. By using this parameter, you can optionally create or not create the resources within this module."
  type        = bool
  default     = true
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

variable "kms_key_deletion_window_in_days" {
  description = "The number of days to retain this KMS Key (a Customer Master Key) after it has been marked for deletion. Setting to null defaults to the provider default, which is the maximum possible value (30 days)."
  type        = number
  default     = null
}

variable "create_network_acls" {
  description = "If set to false, this module will NOT create Network ACLs. This is useful if you don't want to use Network ACLs or you want to provide your own Network ACLs outside of this module."
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS FOR DEFAULT SECURITY GROUP AND DEFAULT NACL
# ----------------------------------------------------------------------------------------------------------------------

variable "enable_default_security_group" {
  description = "If set to false, the default security groups will NOT be created."
  type        = bool
  default     = false
}

variable "default_security_group_ingress_rules" {
  description = "The ingress rules to apply to the default security group in the VPC. This is the security group that is used by any resource that doesn't have its own security group attached. The value for this variable must be a map where the keys are a unique name for each rule and the values are objects with the same fields as the ingress block in the aws_default_security_group resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group#ingress-block."
  # Ideally, we'd have a more specific type here, but neither the 'map' nor 'object' type has support for optional
  # fields, and we need optional fields when defining security group rules.
  type = any
  default = {
    # The default AWS configures:
    # https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html#DefaultSecurityGroup
    AllowAllFromSelf = {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      self      = true
    }
  }
}

variable "default_security_group_egress_rules" {
  description = "The egress rules to apply to the default security group in the VPC. This is the security group that is used by any resource that doesn't have its own security group attached. The value for this variable must be a map where the keys are a unique name for each rule and the values are objects with the same fields as the egress block in the aws_default_security_group resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group#egress-block."
  # Ideally, we'd have a more specific type here, but neither the 'map' nor 'object' type has support for optional
  # fields, and we need optional fields when defining security group rules.
  type = any
  default = {
    # The default AWS configures:
    # https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html#DefaultSecurityGroup
    AllowAllOutbound = {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
}

variable "apply_default_nacl_rules" {
  description = "If true, will apply the default NACL rules in var.default_nacl_ingress_rules and var.default_nacl_egress_rules on the default NACL of the VPC. Note that every VPC must have a default NACL - when this is false, the original default NACL rules managed by AWS will be used."
  type        = bool
  default     = false
}

variable "associate_default_nacl_to_subnets" {
  description = "If true, will associate the default NACL to the public, private, and persistence subnets created by this module. Only used if var.apply_default_nacl_rules is true. Note that this does not guarantee that the subnets are associated with the default NACL. Subnets can only be associated with a single NACL. The default NACL association will be dropped if the subnets are associated with a custom NACL later."
  type        = bool
  default     = true
}

variable "default_nacl_ingress_rules" {
  description = "The ingress rules to apply to the default NACL in the VPC. This is the NACL that is used by any subnet that doesn't have its own NACL attached. The value for this variable must be a map where the keys are a unique name for each rule and the values are objects with the same fields as the ingress block in the aws_default_network_acl resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl."
  # Ideally, we'd have a more specific type here, but neither the 'map' nor 'object' type has support for optional
  # fields, and we need optional fields when defining security group rules.
  type = any
  default = {
    # The default AWS configures:
    # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#default-network-acl
    AllowAll = {
      from_port  = 0
      to_port    = 0
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
      rule_no    = 100
    }
  }
}

variable "default_nacl_egress_rules" {
  description = "The egress rules to apply to the default NACL in the VPC. This is the security group that is used by any subnet that doesn't have its own NACL attached. The value for this variable must be a map where the keys are a unique name for each rule and the values are objects with the same fields as the egress block in the aws_default_network_acl resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl."
  # Ideally, we'd have a more specific type here, but neither the 'map' nor 'object' type has support for optional
  # fields, and we need optional fields when defining security group rules.
  type = any
  default = {
    # The default AWS configures:
    # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#default-network-acl
    AllowAll = {
      from_port  = 0
      to_port    = 0
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
      rule_no    = 100
    }
  }
}

variable "iam_role_permissions_boundary" {
  description = "The ARN of the policy that is used to set the permissions boundary for the IAM role."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# BACKWARD COMPATIBILITY FEATURE FLAGS
# The following variables are feature flags to enable and disable certain features in the module. These are primarily
# introduced to maintain backward compatibility by avoiding unnecessary resource creation.
# ---------------------------------------------------------------------------------------------------------------------

variable "use_managed_iam_policies" {
  description = "When true, all IAM policies will be managed as dedicated policies rather than inline policies attached to the IAM roles. Dedicated managed policies are friendlier to automated policy checkers, which may scan a single resource for findings. As such, it is important to avoid inline policies when targeting compliance with various security standards."
  type        = bool
  default     = true
}
