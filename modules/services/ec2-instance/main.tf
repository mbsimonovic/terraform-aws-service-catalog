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
# LAUNCH THE EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_instance" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-server.git//modules/single-server?ref=v0.14.1"

  name             = var.name
  instance_type    = var.instance_type
  ami              = module.ec2_baseline.existing_ami
  user_data_base64 = module.ec2_baseline.cloud_init_rendered
  tenancy          = var.tenancy
  attach_eip       = var.attach_eip

  # If var.instance_type references an instance type that is not compatible with EBS optimization, set the value to false.
  # Otherwise, use the value of var.ebs_optimized. This check works by first examining the first two characters in var.ebs_optimized
  # For example, if the first two characters are "t2", which is explicitly defined in the local list ebs_optimized_incompatible, then
  # this check will return false, as attempting to enable ebs_optimization on a t2 instance will return an error
  ebs_optimized = (contains(local.ebs_optimized_incompatible, substr(trimspace(var.instance_type), 0, 2)) ? false : var.ebs_optimized)

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  dns_zone_id = var.route53_zone_id != "" ? var.route53_zone_id : (length(data.aws_route53_zone.selected) > 0 ? data.aws_route53_zone.selected[0].zone_id : "")

  # The A record that will be created for the EC2 instance is the concatenation of the instance's name plus the domain name
  dns_name            = var.route53_lookup_domain_name != "" ? "${var.name}.${var.route53_lookup_domain_name}" : "${var.name}.${var.fully_qualified_domain_name}"
  dns_type            = "A"
  dns_ttl             = tostring(var.dns_ttl)
  dns_uses_private_ip = var.dns_zone_is_private

  keypair_name = var.keypair_name

  allow_ssh_from_cidr_list          = var.allow_ssh_from_cidr_blocks
  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids
  additional_security_group_ids     = var.additional_security_group_ids

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
# THE USER DATA SCRIPT THAT WILL RUN ON THE INSTANCE DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # A list of instance types that are not compatible with EBS optimization
  ebs_optimized_incompatible = ["t2"]

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
      ebs_volume_data                     = base64encode(jsonencode(aws_ebs_volume.ec2_instance))
      ebs_volumes                         = base64encode(jsonencode(var.ebs_volumes))
      ebs_aws_region                      = data.aws_region.current.name
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
  iam_role_name                       = module.ec2_instance.iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_instance_cloudwatch_alarms   = var.enable_cloudwatch_alarms
  instance_id                         = module.ec2_instance.id
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters

  should_create_cloudwatch_log_group     = var.should_create_cloudwatch_log_group
  cloudwatch_log_group_name              = var.name
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = var.cloudwatch_log_group_kms_key_id
  cloudwatch_log_group_tags              = var.cloudwatch_log_group_tags

  # Backward compatibility feature flag
  use_managed_iam_policies = var.use_managed_iam_policies
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
  encrypted         = lookup(each.value, "encrypted", false)
  iops              = lookup(each.value, "iops", null)
  snapshot_id       = lookup(each.value, "snapshot_id", null)
  kms_key_id        = lookup(each.value, "kms_key_id", null)
  throughput        = lookup(each.value, "throughput", null)


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
  count = local.use_inline_policies ? 1 : 0

  name   = "manage-ebs-volume"
  role   = module.ec2_instance.iam_role_id
  policy = data.aws_iam_policy_document.manage_ebs_volume.json
}

resource "aws_iam_policy" "manage_ebs_volume" {
  count = var.use_managed_iam_policies ? 1 : 0

  name_prefix = "manage-ebs-volume"
  policy      = data.aws_iam_policy_document.manage_ebs_volume.json
}

resource "aws_iam_role_policy_attachment" "manage_ebs_volume" {
  count = var.use_managed_iam_policies ? 1 : 0

  role       = module.ec2_instance.iam_role_id
  policy_arn = aws_iam_policy.manage_ebs_volume[0].arn
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
