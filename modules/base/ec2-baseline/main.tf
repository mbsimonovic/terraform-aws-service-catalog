
# ---------------------------------------------------------------------------------------------------------------------
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy to our bastion host that allows ssh-grunt to make API calls to IAM to fetch IAM user and group
# data.
# ---------------------------------------------------------------------------------------------------------------------

module "ssh_grunt_policies" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.25.1"

  aws_account_id = data.aws_caller_identity.current.account_id

  # ssh-grunt is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  # Since our IAM users are defined in a separate AWS account, we need to give ssh-grunt permission to make API calls to
  # that account.
  allow_access_to_other_account_arns = var.external_account_ssh_grunt_role_arn == "" ? [] : [var.external_account_ssh_grunt_role_arn]
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  count  = var.enable_ssh_grunt ? 1 : 0
  name   = "ssh-grunt-permissions"
  role   = var.iam_role_arn
  policy = var.external_account_ssh_grunt_role_arn == "" ? module.ssh_grunt_policies.ssh_grunt_permissions : module.ssh_grunt_policies.allow_access_to_other_accounts[0]
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.19.0"

  name_prefix = var.name

  # We set this to false so that the cloudwatch-custom-metrics-iam-policy generates the JSON for the policy, but does
  # not create a standalone IAM policy with that JSON. We'll instead add that JSON to the Jenkins IAM role.
  create_resources = false
}

resource "aws_iam_role_policy" "custom_cloudwatch_metrics" {
  count  = var.enable_cloudwatch_metrics ? 1 : 0
  name   = "custom-cloudwatch-metrics"
  role   = var.iam_role_arn
  policy = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions_json
}

# ------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.19.0"

  name_prefix = var.name

  # We set this to false so that the cloudwatch-log-aggregation-iam-policy generates the JSON for the policy, but does
  # not create a standalone IAM policy with that JSON. We'll instead add that JSON to the Jenkins IAM role.
  create_resources = false
}

resource "aws_iam_role_policy" "cloudwatch_log_aggregation" {
  count  = var.enable_cloudwatch_log_aggregation ? 1 : 0
  name   = "cloudwatch-log-aggregation"
  role   = var.iam_role_arn
  policy = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CPU, MEMORY, OR DISK USAGE ON AN INSTANCE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_instance_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-cpu-alarms?ref=v0.19.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}

module "high_instance_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-memory-alarms?ref=v0.19.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}

module "high_instance_disk_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-disk-alarms?ref=v0.19.0"

  instance_ids         = [var.instance_id]
  instance_count       = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_instance_cloudwatch_alarms
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE CPU, MEMORY, OR DISK USAGE FOR INSTANCES IN AN ASG GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_asg_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.18.3"

  asg_names            = [var.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

module "high_asg_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.18.3"

  asg_names            = [var.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

module "high_asg_disk_usage_root_volume_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.18.3"

  asg_names            = [var.asg_name]
  num_asg_names        = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_asg_cloudwatch_alarms
}

# ---------------------------------------------------------------------------------------------------------------------
# COMBINE MULTIPLE CLOUD-INIT SCRIPTS
# ---------------------------------------------------------------------------------------------------------------------

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  dynamic "part" {
    for_each = var.cloud_init_parts

    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}