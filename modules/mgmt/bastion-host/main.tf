# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH THE BASTION HOST
# The bastion host is the sole point of entry to the network. This way, we can make all other servers inaccessible from
# the public Internet and focus our efforts on locking down the bastion host.
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
# LAUNCH THE BASTION HOST
# ---------------------------------------------------------------------------------------------------------------------

module "bastion" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-server.git//modules/single-server?ref=v0.14.1"

  name             = var.name
  instance_type    = var.instance_type
  ami              = module.ec2_baseline.existing_ami
  user_data_base64 = module.ec2_baseline.cloud_init_rendered
  tenancy          = var.tenancy
  ebs_optimized    = var.ebs_optimized

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  dns_zone_id = var.create_dns_record ? join("", data.aws_route53_zone.selected.*.zone_id) : ""
  # The A record that will be created for the bastion host is the concatenation of the bastion host's name plus the domain name
  dns_name = "${var.name}.${var.domain_name}"
  dns_type = "A"
  dns_ttl  = "300"

  keypair_name                  = var.keypair_name
  allow_ssh_from_cidr_list      = var.allow_ssh_from_cidr_list
  additional_security_group_ids = var.additional_security_group_ids
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP ZONE ID BY DOMAIN NAME
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "selected" {
  count = var.create_dns_record ? 1 : 0

  name = var.domain_name

  tags = var.base_domain_name_tags
  # Since our bastion host needs to be publicly addressable, we need only look up Route 53 Public Hosted zones when querying for the zone_id
  private_zone = false
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON THE BASTION HOST DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "bastion-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  ip_lockdown_users = [var.default_user]
  # We want a space separated list of the users, quoted with ''
  ip_lockdown_users_bash_array = join(
    " ",
    [for user in local.ip_lockdown_users : "'${user}'"],
  )

  # Trim excess whitespace, because AWS will do that on deploy. This prevents
  # constant redeployment because the userdata hash doesn't match the trimmed
  # userdata hash.
  # See: https://github.com/hashicorp/terraform-provider-aws/issues/5011#issuecomment-878542063
  base_user_data = trimspace(templatefile(
    "${path.module}/user-data.sh",
    {
      log_group_name                      = var.name
      enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
      enable_ssh_grunt                    = var.enable_ssh_grunt
      enable_fail2ban                     = var.enable_fail2ban
      enable_ip_lockdown                  = var.enable_ip_lockdown
      ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
      ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
      external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
      ip_lockdown_users                   = local.ip_lockdown_users_bash_array
    },
  ))
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
  iam_role_name                       = module.bastion.iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_instance_cloudwatch_alarms   = var.enable_cloudwatch_alarms
  instance_id                         = module.bastion.id
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters

  should_create_cloudwatch_log_group     = var.should_create_cloudwatch_log_group
  cloudwatch_log_group_name              = var.name
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = var.cloudwatch_log_group_kms_key_id
  cloudwatch_log_group_tags              = var.cloudwatch_log_group_tags

  # Backward compatibility feature flags
  use_managed_iam_policies = var.use_managed_iam_policies
}
