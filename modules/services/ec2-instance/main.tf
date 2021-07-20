terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH THE EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_instance" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-server.git//modules/single-server?ref=v0.12.3"

  name             = var.name
  instance_type    = var.instance_type
  ami              = module.ec2_baseline.existing_ami
  user_data_base64 = module.ec2_baseline.cloud_init_rendered
  tenancy          = var.tenancy

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  dns_zone_id = var.route53_zone_id != "" ? var.route53_zone_id : (length(data.aws_route53_zone.selected) > 0 ? data.aws_route53_zone.selected[0].zone_id : "")

  # The A record that will be created for the EC2 instance is the concatenation of the instance's name plus the domain name
  dns_name = var.route53_lookup_domain_name != "" ? "${var.name}.${var.route53_lookup_domain_name}" : "${var.name}.${var.fully_qualified_domain_name}"
  dns_type = "A"
  dns_ttl  = tostring(var.dns_ttl)

  keypair_name = var.keypair_name

  allow_ssh_from_cidr_list          = var.allow_ssh_from_cidr_blocks
  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids

  root_volume_type                  = var.root_volume_type
  root_volume_size                  = var.root_volume_size
  root_volume_delete_on_termination = var.root_volume_delete_on_termination

  # We want to set the name of the resource with var.name, but all other tags should be settable with var.tags.
  tags = merge(
    { "Name" = var.name },
    var.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP ZONE ID BY DOMAIN NAME
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "selected" {
  count = (var.create_dns_record && var.route53_lookup_domain_name != "") ? 1 : 0

  name = var.route53_lookup_domain_name

  tags = var.base_domain_name_tags
  # Since our host may need to be publicly addressable, we look up Route 53 Public Hosted zones when querying for the zone_id 
  private_zone = var.dns_zone_is_private
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL WILL RUN ON THE INSTANCE DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "ec2-server-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  ip_lockdown_users = compact([var.default_user])
  # We want a space separated list of the users, quoted with ''
  ip_lockdown_users_bash_array = join(
    " ",
    [for user in local.ip_lockdown_users : "'${user}'"],
  )

  base_user_data = templatefile(
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
      ebs_volume_data                     = base64encode(jsonencode(aws_ebs_volume.ec2_instance))
      ebs_volumes                         = base64encode(jsonencode(var.ebs_volumes))
      ebs_aws_region                      = data.aws_region.current.name
    },
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
  iam_role_name                       = module.ec2_instance.iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_instance_cloudwatch_alarms   = var.enable_cloudwatch_alarms
  instance_id                         = module.ec2_instance.id
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters
}

data "aws_subnet" "ec2_instance" {
  id = var.subnet_id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE EBS VOLUMES
# If you have an EBS Volume Snapshot from which the new EBS Volume should be created, add a snapshot_id parameter.
# ---------------------------------------------------------------------------------------------------------------------

# We will attach this volume by ID
resource "aws_ebs_volume" "ec2_instance" {
  for_each          = var.ebs_volumes
  availability_zone = data.aws_subnet.ec2_instance.availability_zone
  type              = each.value.type
  size              = each.value.size
  encrypted         = lookup(var.ebs_volumes, "encrypted", false)
  iops              = lookup(var.ebs_volumes, "iops", null)
  snapshot_id       = lookup(var.ebs_volumes, "snapshot_id", null)
  kms_key_id        = lookup(var.ebs_volumes, "kms_key_id", null)
  throughput        = lookup(var.ebs_volumes, "throughput", null)


  # We want to set the name of the volume from the ebs_volumes map, but all other tags should be settable with var.tags.
  tags = merge(
    { "Name" = each.key },
    var.tags,
  )

}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE INSTANCE TO ATTACH VOLUMES
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "manage_ebs_volume" {
  name   = "manage-ebs-volume"
  role   = module.ec2_instance.iam_role_id
  policy = data.aws_iam_policy_document.manage_ebs_volume.json
}

data "aws_iam_policy_document" "manage_ebs_volume" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]

    resources = concat(
      values(aws_ebs_volume.ec2_instance)[*].arn,
      [
        "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${module.ec2_instance.id}"
      ]
    )
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeVolumes", "ec2:DescribeTags"]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE OPTIONAL PORT INGRESS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_inbound_port_from_cidr" {
  for_each          = var.allow_port_from_cidr_blocks
  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = module.ec2_instance.security_group_id
}

resource "aws_security_group_rule" "allow_inbound_port_from_security_group" {
  for_each                 = var.allow_port_from_security_group_ids
  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = module.ec2_instance.security_group_id
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------

data "aws_region" "current" {}
