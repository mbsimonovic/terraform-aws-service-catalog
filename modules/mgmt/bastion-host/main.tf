# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH THE BASTION HOST
# The bastion host is the sole point of entry to the network. This way, we can make all other servers inaccessible from
# the public Internet and focus our efforts on locking down the bastion host.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH THE BASTION HOST
# ---------------------------------------------------------------------------------------------------------------------

module "bastion" {
  #source = "git::git@github.com:gruntwork-io/module-server.git//modules/single-server?ref=v0.8.1"
  source = "../../../../module-server/modules/single-server"

  name             = var.name
  instance_type    = var.instance_type
  ami              = var.ami
  user_data_base64 = data.template_cloudinit_config.cloud_init.rendered
  tenancy          = var.tenancy

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  keypair_name             = var.keypair_name
  allow_ssh_from_cidr_list = var.allow_ssh_from_cidr_list
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL WILL RUN ON THE BASTION HOST DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "bastion-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = data.template_file.user_data.rendered
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  dynamic "part" {
    for_each = local.cloud_init_parts

    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    vpc_name                            = var.vpc_name
    log_group_name                      = var.name
    enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
    enable_ssh_grunt                    = var.enable_ssh_grunt
    enable_fail2ban                     = var.enable_fail2ban
    ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
    ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
    external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  }
}

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
  role   = module.bastion.iam_role_id
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
  role   = module.bastion.iam_role_id
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
  role   = module.bastion.iam_role_id
  policy = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE BASTION HOST'S CPU, MEMORY, OR DISK USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-cpu-alarms?ref=v0.19.0"

  instance_ids         = [module.bastion.id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

module "high_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-memory-alarms?ref=v0.19.0"

  instance_ids         = [module.bastion.id]
  instance_count       = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

module "high_disk_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ec2-disk-alarms?ref=v0.19.0"

  instance_ids         = [module.bastion.id]
  instance_count       = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A DNS A RECORD FOR THE SERVER
# Create an A Record in Route 53 pointing to the IP of this server so you can connect to it using a nice domain name
# like foo.your-company.com.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "bastion_host" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [module.bastion.public_ip]
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
