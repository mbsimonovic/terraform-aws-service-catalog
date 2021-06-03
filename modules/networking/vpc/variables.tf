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

variable "custom_tags" {
  description = "A map of tags to apply to the VPC, Subnets, Route Tables, Internet Gateway, default security group, and default NACLs. The key is the tag name and the value is the tag value. Note that the tag 'Name' is automatically added by this module but may be optionally overwritten by this variable."
  type        = map(string)
  default     = {}
}

variable "vpc_custom_tags" {
  description = "A map of tags to apply just to the VPC itself, but not any of the other resources. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "public_subnet_custom_tags" {
  description = "A map of tags to apply to the public Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "private_app_subnet_custom_tags" {
  description = "A map of tags to apply to the private-app Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "private_persistence_subnet_custom_tags" {
  description = "A map of tags to apply to the private-persistence Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "nat_gateway_custom_tags" {
  description = "A map of tags to apply to the NAT gateways, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
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

variable "num_availability_zones" {
  description = "How many AWS Availability Zones (AZs) to use. One subnet of each type (public, private app) will be created in each AZ. Note that this must be less than or equal to the total number of AZs in a region. A value of null means all AZs should be used. For example, if you specify 3 in a region with 5 AZs, subnets will be created in just 3 AZs instead of all 5. Defaults to all AZs in a region."
  type        = number
  default     = null
}

variable "availability_zone_exclude_names" {
  description = "Specific Availability Zones in which subnets SHOULD NOT be created. Useful for when features / support is missing from a given AZ."
  type        = list(string)
  default     = []
}

variable "create_public_subnets" {
  description = "If set to false, this module will NOT create the public subnet tier. This is useful for VPCs that only need private subnets. Note that setting this to false also means the module will NOT create an Internet Gateway or the NAT gateways, so if you want any public Internet access in the VPC (even outbound access—e.g., to run apt get), you'll need to provide it yourself via some other mechanism (e.g., via VPC peering, a Transit Gateway, Direct Connect, etc)."
  type        = bool
  default     = true
}

variable "create_private_app_subnets" {
  description = "If set to false, this module will NOT create the private app subnet tier."
  type        = bool
  default     = true
}

variable "create_private_persistence_subnets" {
  description = "If set to false, this module will NOT create the private persistence subnet tier."
  type        = bool
  default     = true
}

variable "create_network_acls" {
  description = "If set to false, this module will NOT create Network ACLs. This is useful if you don't want to use Network ACLs or you want to provide your own Network ACLs outside of this module."
  type        = bool
  default     = true
}

variable "create_public_subnet_nacls" {
  description = "If set to false, this module will NOT create the NACLs for the public subnet tier. This is useful for VPCs that only need private subnets."
  type        = bool
  default     = true
}

variable "create_private_app_subnet_nacls" {
  description = "If set to false, this module will NOT create the NACLs for the private app subnet tier."
  type        = bool
  default     = true
}

variable "create_private_persistence_subnet_nacls" {
  description = "If set to false, this module will NOT create the NACLs for the private persistence subnet tier."
  type        = bool
  default     = true
}

variable "subnet_spacing" {
  description = "The amount of spacing between the different subnet types"
  type        = number
  default     = 10
}

variable "private_subnet_spacing" {
  description = "The amount of spacing between private app subnets. Defaults to subnet_spacing in vpc-app module in not set."
  type        = number
  default     = null
}

variable "persistence_subnet_spacing" {
  description = "The amount of spacing between the private persistence subnets. Default: 2 times the value of private_subnet_spacing."
  type        = number
  default     = null
}

variable "public_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 5
}

variable "private_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 5
}

variable "persistence_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 5
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS FOR DEFAULT SECURITY GROUP AND DEFAULT NACL
# ----------------------------------------------------------------------------------------------------------------------

variable "enable_default_security_group" {
  description = "If set to false, the default security groups will NOT be created."
  type        = bool
  default     = true
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

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS FOR VPC PEERING AND DNS FORWARDING
# ----------------------------------------------------------------------------------------------------------------------

variable "private_app_allow_inbound_ports_from_cidr" {
  description = "A map of unique names to client IP CIDR block and inbound ports that should be exposed in the private app subnet tier nACLs. This is useful when exposing your service on a privileged port with an NLB, where the address isn't translated."
  type = map(
    object({
      # The CIDR block of the client IP addresses for the service. Traffic will only be exposed to IP sources of this
      # CIDR block.
      client_cidr_block = string

      # A rule number indicating priority. A lower number has precedence. Note that the default rules created by this
      # module start with 100.
      rule_number = number

      # Network protocol (tcp, udp, icmp, or all) to expose.
      protocol = string

      # Range of ports to expose.
      from_port = number
      to_port   = number
    })
  )
  default = {}
}

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

variable "origin_vpc_resolver_name" {
  description = "Name to set for the origin VPC resolver (outbound from origin VPC to destination VPC). If null (default), defaults to 'ORIGIN_VPC_NAME-to-DESTINATION_VPC_NAME-out'."
  type        = string
  default     = null
}

variable "destination_vpc_resolver_name" {
  description = "Name to set for the destination VPC resolver (inbound from origin VPC to destination VPC). If null (default), defaults to 'DESTINATION_VPC_NAME-from-ORIGIN_VPC_NAME-in'."
  type        = string
  default     = null
}
