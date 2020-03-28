# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A VPC
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = "~> 2.6"
  }

  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app?ref=v0.8.2"

  vpc_name   = var.vpc_name
  aws_region = var.aws_region
  tenancy    = var.tenancy

  # The number of NAT Gateways to launch for this VPC. For production VPCs, a NAT Gateway should be placed in each
  # Availability Zone (so likely 3 total), whereas for non-prod VPCs, just one Availability Zone (and hence 1 NAT
  # Gateway) will suffice. Warning: You must have at least this number of Elastic IP's to spare. The default AWS limit
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
  # docs at https://github.com/gruntwork-io/module-vpc/blob/master/modules/vpc-app/vars.tf for additional detail.

  # The VPC resources need special tags for discoverability by Kubernetes to use with certain features, like deploying
  # ALBs.
  custom_tags                            = local.maybe_vpc_tags[local.maybe_tag_key]
  public_subnet_custom_tags              = local.maybe_public_subnet_tags[local.maybe_tag_key]
  private_app_subnet_custom_tags         = local.maybe_private_app_subnet_tags[local.maybe_tag_key]
  private_persistence_subnet_custom_tags = local.maybe_private_persistence_subnet_tags[local.maybe_tag_key]
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP EKS TAGS
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_tags" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-vpc-tags?ref=v0.19.0"

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
# CREATE THE NETWORK ACLS FOR THE VPC
# Network ACLs provide an extra layer of network security across an entire subnet, whereas security groups provide
# network security on a single resource.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network_acls" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app-network-acls?ref=v0.8.2"

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
  allow_access_from_mgmt_vpc             = false
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE VPC FLOW LOGS
# VPC Flow Logs captures information about the IP traffic going to and from network interfaces in your VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_flow_logs" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-flow-logs?ref=v0.8.2"

  vpc_id                    = module.vpc.vpc_id
  cloudwatch_log_group_name = "${module.vpc.vpc_name}-vpc-flow-logs"
  kms_key_users             = var.kms_key_user_iam_arns
  kms_key_arn               = var.kms_key_arn
  create_resources          = var.create_flow_logs
}

