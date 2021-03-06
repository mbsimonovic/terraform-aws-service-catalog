# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A MANAGEMENT VPC
# To avoid commingling the management systems (e.g. the ecs-deploy-runner) with application traffic, we
# create a management VPC in the baseline configuration.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6, < 4.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-mgmt?ref=v0.20.2"

  aws_region                      = var.aws_region
  vpc_name                        = var.vpc_name
  cidr_block                      = var.cidr_block
  num_nat_gateways                = var.num_nat_gateways
  num_availability_zones          = var.num_availability_zones
  availability_zone_exclude_names = var.availability_zone_exclude_names
  availability_zone_exclude_ids   = var.availability_zone_exclude_ids
  availability_zone_state         = var.availability_zone_state
  public_subnet_bits              = var.public_subnet_bits
  private_subnet_bits             = var.private_subnet_bits
  subnet_spacing                  = var.subnet_spacing
  public_subnet_cidr_blocks       = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks      = var.private_subnet_cidr_blocks
  custom_tags                     = var.custom_tags
  vpc_custom_tags                 = var.custom_tags_vpc_only
  public_subnet_custom_tags       = var.public_subnet_custom_tags
  private_subnet_custom_tags      = var.private_subnet_custom_tags
  nat_gateway_custom_tags         = var.nat_gateway_custom_tags

  # Params for the Default Security Group and Default NACL
  enable_default_security_group        = var.enable_default_security_group
  default_security_group_ingress_rules = var.default_security_group_ingress_rules
  default_security_group_egress_rules  = var.default_security_group_egress_rules
  apply_default_nacl_rules             = var.apply_default_nacl_rules
  associate_default_nacl_to_subnets    = var.associate_default_nacl_to_subnets
  default_nacl_ingress_rules           = var.default_nacl_ingress_rules
  default_nacl_egress_rules            = var.default_nacl_egress_rules
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE VPC FLOW LOGS
# VPC Flow Logs captures information about the IP traffic going to and from network interfaces in your VPC
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_flow_logs" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-flow-logs?ref=v0.20.2"

  vpc_id                          = module.vpc.vpc_id
  cloudwatch_log_group_name       = "${module.vpc.vpc_name}-vpc-flow-logs"
  kms_key_users                   = var.kms_key_user_iam_arns
  kms_key_arn                     = var.kms_key_arn
  kms_key_deletion_window_in_days = var.kms_key_deletion_window_in_days
  create_resources                = var.create_flow_logs
  iam_role_permissions_boundary   = var.iam_role_permissions_boundary
  use_managed_iam_policies        = var.use_managed_iam_policies
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE NETWORK ACLS FOR THE MGMT VPC
# Network ACLs provide an extra layer of network security across an entire subnet, whereas security groups provide
# network security on a single resource.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network_acls" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-vpc.git//modules/vpc-mgmt-network-acls?ref=v0.20.2"

  create_resources = var.create_network_acls

  vpc_id      = module.vpc.vpc_id
  vpc_name    = module.vpc.vpc_name
  vpc_ready   = module.vpc.vpc_ready
  num_subnets = module.vpc.num_availability_zones

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  public_subnet_cidr_blocks  = module.vpc.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = module.vpc.private_subnet_cidr_blocks
}
