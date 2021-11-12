# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN OPENVPN SERVER
# The OpenVPN Server is the sole point of entry to the network. This way, we can make all other servers inaccessible
# from the public Internet and focus our efforts on locking down the OpenVPN Server.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.58"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH THE OPENVPN SERVER
# ---------------------------------------------------------------------------------------------------------------------

module "openvpn" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-openvpn.git//modules/openvpn-server?ref=v0.17.0"

  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id

  name = var.name

  instance_type    = var.instance_type
  ami              = module.ec2_baseline.existing_ami
  user_data_base64 = module.ec2_baseline.cloud_init_rendered

  request_queue_name    = var.request_queue_name
  revocation_queue_name = var.revocation_queue_name

  keypair_name       = var.keypair_name
  kms_key_arn        = local.kms_key_arn
  backup_bucket_name = var.backup_bucket_name

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  external_account_arns = var.external_account_arns

  allow_vpn_from_cidr_list = var.allow_vpn_from_cidr_list
  allow_ssh_from_cidr_list = var.allow_ssh_from_cidr_list
  allow_ssh_from_cidr      = true

  backup_bucket_force_destroy = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON THE OPENVPN SERVER DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # init-openvpn expects the subnet routes in [subnet] [mask] format (e.g., "10.100.0.0 255.255.255.0"), so we
  # need to translate the CIDR blocks to this format.
  vpn_subnet_routes = [for cidr_block in var.vpn_route_cidr_blocks : "'${cidrhost(cidr_block, 0)} ${cidrnetmask(cidr_block)}'"]

  extra_args = flatten(
    concat(
      [for route in local.vpn_subnet_routes : ["--vpn-route", route]],
      [for domain in var.vpn_search_domains : ["--search-domain", "'${domain}'"]],
    )
  )

  ip_lockdown_users = [var.default_user]
  # We want a space separated list of the users, quoted with ''
  ip_lockdown_users_bash_array = join(
    " ",
    [for user in local.ip_lockdown_users : "'${user}'"],
  )

  user_data_vars = {
    backup_bucket_name = module.openvpn.backup_bucket_name
    kms_key_arn        = local.kms_key_arn

    key_size             = 4096
    ca_expiration_days   = 3650
    cert_expiration_days = 3650

    ca_country  = var.ca_cert_fields.ca_country
    ca_state    = var.ca_cert_fields.ca_state
    ca_locality = var.ca_cert_fields.ca_locality
    ca_org      = var.ca_cert_fields.ca_org
    ca_org_unit = var.ca_cert_fields.ca_org_unit
    ca_email    = var.ca_cert_fields.ca_email

    eip_id = module.openvpn.elastic_ip

    request_queue_url    = module.openvpn.client_request_queue
    revocation_queue_url = module.openvpn.client_revocation_queue
    queue_region         = data.aws_region.current.name

    vpn_subnet              = var.vpn_subnet
    init_openvpn_extra_args = join(" ", local.extra_args)

    log_group_name                      = "${var.name}_log_group"
    enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
    enable_ssh_grunt                    = var.enable_ssh_grunt
    enable_fail2ban                     = var.enable_fail2ban
    enable_ip_lockdown                  = var.enable_ip_lockdown
    ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
    ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
    external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
    ip_lockdown_users                   = local.ip_lockdown_users_bash_array
  }

  # Default cloud init script for this module
  cloud_init = {
    filename     = "openvpn-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/user-data.sh", local.user_data_vars)
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  # We use a "double conditional" check here to prevent issues during destroy
  # operations in which the key from module.kms_cmk has been deleted but 
  # a subsequent step failed, causing an invalid index error on a subsequent
  # destroy.
  kms_key_arn = (
    var.kms_key_arn != null ?
    var.kms_key_arn :
    length(module.kms_cmk.key_arn) > 0 ?
    module.kms_cmk.key_arn[var.name] :
    ""
  )
  cmk_administrator_iam_arns = length(var.cmk_administrator_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_administrator_iam_arns
  cmk_user_iam_arns          = length(var.cmk_user_iam_arns) == 0 ? [{ name = [data.aws_caller_identity.current.arn], conditions = [] }] : var.cmk_user_iam_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Customer Master Key
# Create a new KMS CMK if an existing KMS key has not been provided in var.kms_key_arn 
# ---------------------------------------------------------------------------------------------------------------------

module "kms_cmk" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-master-key?ref=v0.55.4"
  customer_master_keys = (
    var.kms_key_arn == null
    ? {
      (var.name) = {
        cmk_administrator_iam_arns = local.cmk_administrator_iam_arns
        cmk_user_iam_arns          = local.cmk_user_iam_arns
        cmk_external_user_iam_arns = var.cmk_external_user_iam_arns

        # The IAM role of the OpenVPN server needs access to use the KMS key, and those permissions are managed with IAM
        allow_manage_key_permissions_with_iam = true
      }
    }
    : {}
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# BASE RESOURCES
# Includes resources common to all EC2 instances in the Service Catalog, including permissions
# for ssh-grunt, CloudWatch Logs aggregation, CloudWatch metrics, and CloudWatch alarms
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name                                = var.name
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  enable_ssh_grunt                    = var.enable_ssh_grunt
  enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
  iam_role_name                       = module.openvpn.iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = var.enable_cloudwatch_alarms
  asg_names                           = [module.openvpn.autoscaling_group_id]
  num_asg_names                       = 1
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A DNS A RECORD FOR THE SERVER
# Create an A Record in Route 53 pointing to the IP of this server so you can connect to it using a nice domain name
# like foo.your-company.com.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "openvpn" {
  count = var.create_route53_entry ? 1 : 0
  name = (
    var.domain_name == null
    ? "${var.name}.${var.base_domain_name}"
    : var.domain_name
  )
  zone_id = (
    length(data.aws_route53_zone.selected) > 0 ? data.aws_route53_zone.selected[0].zone_id : var.hosted_zone_id
  )
  type    = "A"
  ttl     = "300"
  records = [module.openvpn.public_ip]
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMICALLY LOOK UP THE ZONE ID OF SUPPLIED DOMAIN NAME
# Look up the zone ID associated with var.base_domain_name. This makes usage of this module simpler as the zone ID does
# not have to be supplied as an argument.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "selected" {
  # We only need to perform a dynamic lookup of the zone ID if the hosted_zone_id was NOT supplied as an input.
  count = var.create_route53_entry && var.hosted_zone_id == null ? 1 : 0
  name  = var.base_domain_name

  tags = var.base_domain_name_tags != null ? var.base_domain_name_tags : {}

  private_zone = false
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
