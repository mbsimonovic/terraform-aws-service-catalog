terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 2.0, < 4.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy that allows ssh-grunt to make API calls to IAM to fetch IAM user and group
# data.
# ---------------------------------------------------------------------------------------------------------------------

module "ssh_grunt_policies" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-policies?ref=v0.62.3"

  aws_account_id = data.aws_caller_identity.current.account_id

  # ssh-grunt is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  # Since our IAM users are defined in a separate AWS account, we need to give ssh-grunt permission to make API calls to
  # that account. The input takes a map with group name as the key, but the key is only used in the output. In this case,
  # we won't use the output, so the "ssh-grunt" key is just a placeholder.
  allow_access_to_other_account_arns = var.external_account_ssh_grunt_role_arn == "" ? {} : { "ssh-grunt" = [var.external_account_ssh_grunt_role_arn] }
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  count = var.enable_ssh_grunt && local.use_inline_policies ? 1 : 0

  name   = "ssh-grunt-permissions"
  role   = var.iam_role_name
  policy = var.external_account_ssh_grunt_role_arn == "" ? module.ssh_grunt_policies.ssh_grunt_permissions : module.ssh_grunt_policies.allow_access_to_other_accounts["ssh-grunt"]
}

resource "aws_iam_policy" "ssh_grunt_permissions" {
  count = var.enable_ssh_grunt && var.use_managed_iam_policies ? 1 : 0

  name_prefix = "ssh-grunt-permissions"
  description = "IAM Policy to allow ssh-grunt permission to make API calls to other accounts."
  policy      = var.external_account_ssh_grunt_role_arn == "" ? module.ssh_grunt_policies.ssh_grunt_permissions : module.ssh_grunt_policies.allow_access_to_other_accounts["ssh-grunt"]
}

resource "aws_iam_role_policy_attachment" "ssh_grunt_permissions" {
  count = var.enable_ssh_grunt && var.use_managed_iam_policies ? 1 : 0

  role       = var.iam_role_name
  policy_arn = aws_iam_policy.ssh_grunt_permissions[0].arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.32.0"

  name_prefix = var.name

  create_resources = false
}

resource "aws_iam_role_policy" "custom_cloudwatch_metrics" {
  count = var.enable_cloudwatch_metrics && local.use_inline_policies ? 1 : 0

  name   = "custom-cloudwatch-metrics"
  role   = var.iam_role_name
  policy = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions_json
}

resource "aws_iam_policy" "custom_cloudwatch_metrics" {
  count = var.enable_cloudwatch_metrics && var.use_managed_iam_policies ? 1 : 0

  name_prefix = "custom-cloudwatch-metrics"
  description = "IAM Policy to allow access to CloudWatch metrics."
  policy      = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions_json
}

resource "aws_iam_role_policy_attachment" "custom_cloudwatch_metrics" {
  count = var.enable_cloudwatch_metrics && var.use_managed_iam_policies ? 1 : 0

  role       = var.iam_role_name
  policy_arn = aws_iam_policy.custom_cloudwatch_metrics[0].arn
}

# ------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.32.0"

  name_prefix = var.name

  create_resources = false
}

resource "aws_iam_role_policy" "cloudwatch_log_aggregation" {
  count = var.enable_cloudwatch_log_aggregation && local.use_inline_policies ? 1 : 0

  name   = "cloudwatch-log-aggregation"
  role   = var.iam_role_name
  policy = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

resource "aws_iam_policy" "cloudwatch_log_aggregation" {
  count = var.enable_cloudwatch_metrics && var.use_managed_iam_policies ? 1 : 0

  name_prefix = "cloudwatch-log-aggregation"
  description = "IAM Policy to allow CloudWatch log aggregation."
  policy      = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_log_aggregation" {
  count = var.enable_cloudwatch_metrics && var.use_managed_iam_policies ? 1 : 0

  role       = var.iam_role_name
  policy_arn = aws_iam_policy.cloudwatch_log_aggregation[0].arn
}

# ------------------------------------------------------------------------------
# ADD CLOUDWATCH LOG GROUP TO ALLOW FURTHER CUSTOMIZATION
# The CloudWatch agent installed on the instances will automatically create the
# CloudWatch Log Group, but the configuration options are fairly basic.
# Therefore, we manage the CloudWatch Log Group here in Terraform to offer the
# full range of configuration options on the group.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "log_aggregation" {
  count = var.enable_cloudwatch_log_aggregation && var.should_create_cloudwatch_log_group ? 1 : 0

  name              = var.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  tags              = var.cloudwatch_log_group_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CPU, MEMORY, OR DISK USAGE ON AN INSTANCE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_instance_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ec2-cpu-alarms?ref=v0.32.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}

module "high_instance_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ec2-memory-alarms?ref=v0.32.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}

module "high_instance_disk_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ec2-disk-alarms?ref=v0.32.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  device               = "xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CPU, MEMORY, OR DISK USAGE FOR INSTANCES IN AN ASG GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_asg_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.32.0"

  asg_names            = var.asg_names
  num_asg_names        = var.num_asg_names
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

module "high_asg_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.32.0"

  asg_names            = var.asg_names
  num_asg_names        = var.num_asg_names
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

module "high_asg_disk_usage_root_volume_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.32.0"

  asg_names            = var.asg_names
  num_asg_names        = var.num_asg_names
  device               = "xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

# ---------------------------------------------------------------------------------------------------------------------
# COMBINE MULTIPLE CLOUD-INIT SCRIPTS
# ---------------------------------------------------------------------------------------------------------------------

data "cloudinit_config" "cloud_init" {
  # Ideally, we could use var.cloud_init_parts in the count conditional. However,
  # the value may not be known until runtime, and hence using that may result in an error.
  # Instead, we fall back to a boolean.
  count = var.should_render_cloud_init ? 1 : 0

  gzip          = true
  base64_encode = true

  # NOTE: We extract out the default cloud init part first, and then render the rest. This ensures the default cloud
  # init configuration always runs first.
  dynamic "part" {
    # The contents of the final list don't matter, as this is only used to determine if this section needs to be
    # rendered or not.
    for_each = local.maybe_default_cloudinit == null ? [] : ["enable_default_cloudinit"]

    content {
      filename     = local.maybe_default_cloudinit.filename
      content_type = local.maybe_default_cloudinit.content_type
      content      = local.maybe_default_cloudinit.content
    }
  }

  dynamic "part" {
    # We filter out the default cloud init part since we already rendered that above.
    for_each = {
      for k, v in var.cloud_init_parts :
      k => v if k != "default"
    }

    content {
      filename     = part.value.filename
      content_type = part.value.content_type
      content      = part.value.content
    }
  }
}

locals {
  maybe_default_cloudinit = lookup(var.cloud_init_parts, "default", null)
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOKUP EXISTING AMI USING PROVIDED FILTERS
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "existing" {
  count = local.use_ami_lookup ? 1 : 0

  most_recent = true
  owners      = var.ami_filters.owners

  dynamic "filter" {
    for_each = var.ami_filters.filters

    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

locals {
  use_ami_lookup = var.ami_filters != null
}


# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
