# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN OPENVPN SERVER
# The OpenVPN Server is the sole point of entry to the network. This way, we can make all other servers inaccessible
# from the public Internet and focus our efforts on locking down the OpenVPN Server.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH THE OPENVPN SERVER
# ---------------------------------------------------------------------------------------------------------------------

module "openvpn" {
  source = "git::git@github.com:gruntwork-io/module-openvpn.git//modules/openvpn-server?ref=v0.9.11"

  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id

  name = var.name

  instance_type    = var.instance_type
  ami              = var.ami_id
  user_data_base64 = module.ec2_baseline.cloud_init_rendered

  request_queue_name    = var.request_queue_name
  revocation_queue_name = var.revocation_queue_name

  keypair_name       = var.keypair_name
  kms_key_arn        = local.kms_key_arn
  backup_bucket_name = var.backup_bucket_name

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  external_account_arns = var.external_account_arns

  allow_vpn_from_cidr_list = var.allow_vpn_from_cidr_list
  allow_ssh_from_cidr_list = var.allow_ssh_from_cidr_list
  allow_ssh_from_cidr      = true

  backup_bucket_force_destroy = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL WILL RUN ON THE OPENVPN SERVER DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
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

    vpn_subnet = var.vpn_subnet
    routes     = join(" ", formatlist("\"%s\"", var.vpn_route_cidr_blocks))

    log_group_name = "${var.name}_log_group"
  }

  # Default cloud init script for this module
  cloud_init = {
    filename     = "openvpn-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/user-data.sh", local.user_data_vars)
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  kms_key_arn                = var.kms_key_arn != null ? var.kms_key_arn : module.kms_cmk.key_arn[var.name]
  cmk_administrator_iam_arns = length(var.cmk_administrator_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_administrator_iam_arns
  cmk_user_iam_arns          = length(var.cmk_user_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_user_iam_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Customer Master Key
# Create a new KMS CMK if an existing KMS key has not been provided in var.kms_key_arn 
# ---------------------------------------------------------------------------------------------------------------------

module "kms_cmk" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key?ref=v0.27.1"
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
  iam_role_arn                        = module.openvpn.iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = var.enable_cloudwatch_alarms
  asg_names                           = [module.openvpn.autoscaling_group_id]
  num_asg_names                       = 1
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A DNS A RECORD FOR THE SERVER
# Create an A Record in Route 53 pointing to the IP of this server so you can connect to it using a nice domain name
# like foo.your-company.com.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "openvpn" {
  count   = var.domain_name != null ? 1 : 0
  name    = "${var.name}.${var.domain_name}"
  zone_id = var.hosted_zone_id
  type    = "A"
  ttl     = "300"
  records = [module.openvpn.public_ip]
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}