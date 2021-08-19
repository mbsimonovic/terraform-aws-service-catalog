# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A VPC
# This will create a VPC with 3 subnet tiers:
# - public
# - private app
# - private persistence
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.69"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-app?ref=v0.17.0"

  vpc_name               = var.vpc_name
  aws_region             = var.aws_region
  tenancy                = var.tenancy
  num_availability_zones = var.num_availability_zones

  # The number of NAT Gateways to launch for this VPC. For production VPCs, a NAT Gateway should be placed in each
  # Availability Zone, whereas for non-production VPCs, just one Availability Zone (and hence 1 NAT
  # Gateway) will suffice. Warning: You must have at least this number of Elastic IP addresses to spare. The default AWS limit
  # is 5 per region, but you can request more.
  num_nat_gateways = var.num_nat_gateways

  # The IP address range of the VPC in CIDR notation. A prefix of /18 is recommended. Do not use a prefix higher
  # than /27.
  cidr_block = var.cidr_block

  # Set this to true to allow servers in the private persistence subnets to make outbound requests to the public
  # Internet via a NAT Gateway. If you're only using AWS services (e.g., RDS) you can leave this as false, but if
  # you're running your own data stores in the private persistence subnets, you'll need to set this to true to allow
  # those servers to talk to the AWS APIs (e.g., CloudWatch, IAM, etc).
  allow_private_persistence_internet_access = var.allow_private_persistence_internet_access

  # Some teams may want to explicitly define the exact CIDR blocks used by their subnets. If so, see the vpc-app vars.tf
  # docs at https://github.com/gruntwork-io/terraform-aws-vpc/blob/master/modules/vpc-app/vars.tf for additional detail.

  availability_zone_exclude_names = var.availability_zone_exclude_names

  # The VPC resources need special tags for discoverability by Kubernetes to use with certain features, like deploying
  # ALBs.
  custom_tags                            = merge(local.maybe_vpc_tags[local.maybe_tag_key], var.custom_tags)
  public_subnet_custom_tags              = merge(local.maybe_public_subnet_tags[local.maybe_tag_key], var.public_subnet_custom_tags)
  private_app_subnet_custom_tags         = merge(local.maybe_private_app_subnet_tags[local.maybe_tag_key], var.private_app_subnet_custom_tags)
  private_persistence_subnet_custom_tags = merge(local.maybe_private_persistence_subnet_tags[local.maybe_tag_key], var.private_persistence_subnet_custom_tags)

  # Other tags to apply to some of the VPC resources
  vpc_custom_tags         = var.vpc_custom_tags
  nat_gateway_custom_tags = var.nat_gateway_custom_tags

  # Params for the Default Security Group and Default NACL
  enable_default_security_group        = var.enable_default_security_group
  default_security_group_ingress_rules = var.default_security_group_ingress_rules
  default_security_group_egress_rules  = var.default_security_group_egress_rules
  apply_default_nacl_rules             = var.apply_default_nacl_rules
  default_nacl_ingress_rules           = var.default_nacl_ingress_rules
  default_nacl_egress_rules            = var.default_nacl_egress_rules

  # Params for enabling/disabling subnet tiers
  create_public_subnets              = var.create_public_subnets
  create_private_app_subnets         = var.create_private_app_subnets
  create_private_persistence_subnets = var.create_private_persistence_subnets

  # Params configuring subnet CIDR spacing
  subnet_spacing             = var.subnet_spacing
  private_subnet_spacing     = var.private_subnet_spacing
  persistence_subnet_spacing = var.persistence_subnet_spacing
  public_subnet_bits         = var.public_subnet_bits
  private_subnet_bits        = var.private_subnet_bits
  persistence_subnet_bits    = var.persistence_subnet_bits

}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VPC PEERING CONNECTIONS
# Although VPCs are normally isolated from each other, they can be peered to allow connectivity between VPC networks
# in the same or different AWS accounts.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  destination_route_tables = concat(
    [module.vpc.public_subnet_route_table_id],
    module.vpc.private_app_subnet_route_table_ids,
    module.vpc.private_persistence_route_table_ids,
  )
}

module "vpc_peering_connection" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-peering?ref=v0.17.0"
  create_resources = var.create_peering_connection

  aws_account_id = data.aws_caller_identity.current.account_id

  origin_vpc_id               = var.origin_vpc_id
  origin_vpc_name             = var.origin_vpc_name
  origin_vpc_cidr_block       = var.origin_vpc_cidr_block
  origin_vpc_route_table_ids  = var.origin_vpc_route_table_ids
  num_origin_vpc_route_tables = length(var.origin_vpc_route_table_ids)

  destination_vpc_id               = module.vpc.vpc_id
  destination_vpc_name             = module.vpc.vpc_name
  destination_vpc_cidr_block       = module.vpc.vpc_cidr_block
  destination_vpc_route_table_ids  = local.destination_route_tables
  num_destination_vpc_route_tables = length(local.destination_route_tables)
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONALLY CREATE DNS FORWARDER BETWEEN PEERED VPCs
# Set up Route 53 Resolvers so that private hosted zones can be resolved between peered VPCs.
# Note: the DNS forwarders (both outbound and inbound) deploy into the public subnets. This means that they are both
# publicly addressable. This is due to restrictions on the network ACLs blocking the functionality of the DNS forwarder.
# Access to the endpoints are protected by security group rules that prevent network access to these endpoint.
# ---------------------------------------------------------------------------------------------------------------------

module "dns_mgmt_to_app" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-dns-forwarder?ref=v0.17.0"
  create_resources = var.create_dns_forwarder

  origin_vpc_id                                   = var.origin_vpc_id
  origin_vpc_name                                 = var.origin_vpc_name
  origin_vpc_route53_resolver_primary_subnet_id   = var.create_dns_forwarder ? var.origin_vpc_public_subnet_ids[0] : null
  origin_vpc_route53_resolver_secondary_subnet_id = var.create_dns_forwarder ? var.origin_vpc_public_subnet_ids[1] : null

  destination_vpc_id                                   = module.vpc.vpc_id
  destination_vpc_name                                 = module.vpc.vpc_name
  destination_vpc_route53_resolver_primary_subnet_id   = var.create_dns_forwarder ? module.vpc.public_subnet_ids[0] : null
  destination_vpc_route53_resolver_secondary_subnet_id = var.create_dns_forwarder ? module.vpc.public_subnet_ids[1] : null

  destination_vpc_resolver_name = var.destination_vpc_resolver_name
  origin_vpc_resolver_name      = var.origin_vpc_resolver_name
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP EKS TAGS
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_tags" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-vpc-tags?ref=v0.44.4"

  eks_cluster_names = var.eks_cluster_names
}

locals {
  # Map keys must be string, so we convert bool to string here using a conditional
  maybe_tag_key = var.tag_for_use_with_eks ? "true" : "false"

  maybe_vpc_tags = {
    "true"  = module.vpc_tags.vpc_eks_tags
    "false" = {}
  }

  maybe_public_subnet_tags = {
    "true"  = module.vpc_tags.vpc_public_subnet_eks_tags
    "false" = {}
  }

  maybe_private_app_subnet_tags = {
    "true"  = module.vpc_tags.vpc_private_app_subnet_eks_tags
    "false" = {}
  }

  maybe_private_persistence_subnet_tags = {
    "true"  = module.vpc_tags.vpc_private_persistence_subnet_eks_tags
    "false" = {}
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE NETWORK ACLs FOR THE VPC
# Network ACLs provide an extra layer of network security across an entire subnet, whereas security groups provide
# network security on a single resource.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network_acls" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-app-network-acls?ref=v0.17.0"

  create_resources                        = var.create_network_acls
  create_public_subnet_nacls              = var.create_public_subnets && var.create_public_subnet_nacls
  create_private_app_subnet_nacls         = var.create_private_app_subnets && var.create_private_app_subnet_nacls
  create_private_persistence_subnet_nacls = var.create_private_persistence_subnets && var.create_private_persistence_subnet_nacls

  vpc_id      = module.vpc.vpc_id
  vpc_name    = module.vpc.vpc_name
  vpc_ready   = module.vpc.vpc_ready
  num_subnets = module.vpc.num_availability_zones

  public_subnet_ids              = module.vpc.public_subnet_ids
  private_app_subnet_ids         = module.vpc.private_app_subnet_ids
  private_persistence_subnet_ids = module.vpc.private_persistence_subnet_ids

  public_subnet_cidr_blocks              = module.vpc.public_subnet_cidr_blocks
  private_app_subnet_cidr_blocks         = module.vpc.private_app_subnet_cidr_blocks
  private_persistence_subnet_cidr_blocks = module.vpc.private_persistence_subnet_cidr_blocks

  # Setup mgmt VPC access if peering is configured
  allow_access_from_mgmt_vpc = var.create_peering_connection
  mgmt_vpc_cidr_block        = var.origin_vpc_cidr_block

  # Setup client access if it is fronted by an NLB
  private_app_allow_inbound_ports_from_cidr = var.private_app_allow_inbound_ports_from_cidr
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE VPC FLOW LOGS
# VPC Flow Logs captures information about the IP traffic going to and from network interfaces in your VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_flow_logs" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-flow-logs?ref=v0.17.0"

  vpc_id                    = module.vpc.vpc_id
  cloudwatch_log_group_name = "${module.vpc.vpc_name}-vpc-flow-logs"
  kms_key_users             = var.kms_key_user_iam_arns
  kms_key_arn               = var.kms_key_arn
  create_resources          = var.create_flow_logs
  traffic_type              = var.flow_logs_traffic_type
}
