# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A VPC
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}

  # Only allow this Terraform version. Note that if you upgrade to a newer version, Terraform won't allow you to use an
  # older version, so when you upgrade, you should upgrade everyone on your team and your CI servers all at once.
  required_version = "= 0.12.17"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app?ref=v0.7.8"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-vpc-tags?ref=v0.8.2"

  eks_cluster_name = var.eks_cluster_name
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
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app-network-acls?ref=v0.7.8"

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
  allow_access_from_mgmt_vpc             = true
  mgmt_vpc_cidr_block                    = data.terraform_remote_state.mgmt_vpc.outputs.vpc_cidr_block
}
# ---------------------------------------------------------------------------------------------------------------------
# ENABLE VPC FLOW LOGS
# VPC Flow Logs captures information about the IP traffic going to and from network interfaces in your VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_flow_logs" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-flow-logs?ref=v0.7.8"

  vpc_id                    = module.vpc.vpc_id
  cloudwatch_log_group_name = "${module.vpc.vpc_name}-vpc-flow-logs"
  kms_key_users             = var.kms_key_user_iam_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE VPC PEERING CONNECTION FROM MGMT TO THIS VPC
# Although VPCs are normally isolated from each other, this allows DevOps tools (e.g. the bastion host, Jenkins)
# limited access to this VPC.
# ---------------------------------------------------------------------------------------------------------------------

module "mgmt_vpc_peering_connection" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-peering?ref=v0.7.8"

  # Assume the first listed AWS Account Id is the one that should own the peering connection
  aws_account_id = var.aws_account_id

  origin_vpc_id         = data.terraform_remote_state.mgmt_vpc.outputs.vpc_id
  origin_vpc_name       = data.terraform_remote_state.mgmt_vpc.outputs.vpc_name
  origin_vpc_cidr_block = data.terraform_remote_state.mgmt_vpc.outputs.vpc_cidr_block
  origin_vpc_route_table_ids = concat(
    data.terraform_remote_state.mgmt_vpc.outputs.private_subnet_route_table_ids,
    [data.terraform_remote_state.mgmt_vpc.outputs.public_subnet_route_table_id]
  )

  # We should be able to compute these numbers automatically, but can't due to a Terraform bug:
  # https://github.com/hashicorp/terraform/issues/3888. Therefore, we make some assumptions: there is one
  # route table per availability zone in private subnets and just one route table in public subnets.
  num_origin_vpc_route_tables = data.terraform_remote_state.mgmt_vpc.outputs.num_availability_zones + 1

  destination_vpc_id         = module.vpc.vpc_id
  destination_vpc_name       = module.vpc.vpc_name
  destination_vpc_cidr_block = module.vpc.vpc_cidr_block
  destination_vpc_route_table_ids = concat(
    [module.vpc.public_subnet_route_table_id],
    module.vpc.private_app_subnet_route_table_ids,
    module.vpc.private_persistence_route_table_ids,
  )

  # We should be able to compute these numbers automatically, but can't due to a Terraform bug:
  # https://github.com/hashicorp/terraform/issues/3888. Therefore, we make some assumptions: there is one
  # route table per availability zone in private subnets and just one route table in public subnets.
  num_destination_vpc_route_tables = (module.vpc.num_availability_zones * 2) + 1
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE DNS FORWARDER BETWEEN MGMT VPC AND APP VPC
# Note: the DNS forwarders (both outbound and inbound) deploy into the public subnets. This means that they are both
# publicly addressable. This is due to restrictions on the network ACLs blocking the functionality of the DNS forwarder.
# Note that access to the endpoints are protected by security group rules that prevent network access to these endpoint.
# ---------------------------------------------------------------------------------------------------------------------

module "dns_mgmt_to_app" {
  source           = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-dns-forwarder?ref=v0.7.8"
  create_resources = var.create_dns_forwarder

  origin_vpc_id                                   = data.terraform_remote_state.mgmt_vpc.outputs.vpc_id
  origin_vpc_name                                 = data.terraform_remote_state.mgmt_vpc.outputs.vpc_name
  origin_vpc_route53_resolver_primary_subnet_id   = element(data.terraform_remote_state.mgmt_vpc.outputs.public_subnet_ids, 0)
  origin_vpc_route53_resolver_secondary_subnet_id = element(data.terraform_remote_state.mgmt_vpc.outputs.public_subnet_ids, 1)

  destination_vpc_id                                   = module.vpc.vpc_id
  destination_vpc_name                                 = module.vpc.vpc_name
  destination_vpc_route53_resolver_primary_subnet_id   = element(module.vpc.public_subnet_ids, 0)
  destination_vpc_route53_resolver_secondary_subnet_id = element(module.vpc.public_subnet_ids, 1)

  name_prefix = "${data.terraform_remote_state.mgmt_vpc.outputs.vpc_name}-to-${module.vpc.vpc_name}-"
}

# ---------------------------------------------------------------------------------------------------------------------
# PULL MGMT VPC DATA FROM THE TERRAFORM REMOTE STATE
# These templates run on top of the VPCs created by the VPC templates, which store their Terraform state files in an S3
# bucket using remote state storage.
# ---------------------------------------------------------------------------------------------------------------------

data "terraform_remote_state" "mgmt_vpc" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/mgmt/vpc/terraform.tfstate"
  }
}
