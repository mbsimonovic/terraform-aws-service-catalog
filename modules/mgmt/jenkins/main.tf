# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY JENKINS
# This module can be used to run a Jenkins server. It creates the following resources:
#
# - An ASG to run Jenkins
# - An EBS volume for Jenkins that persists between redeploys
# - A lambda function to periodically take a snapshot of the EBS volume
# - A CloudWatch alarm that goes off if a backup job fails to run
# - An ALB to route traffic to Jenkins
# - A Route 53 DNS A record pointing at the ALB
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
# LAUNCH JENKINS
# ---------------------------------------------------------------------------------------------------------------------

module "jenkins" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/jenkins-server?ref=v0.18.1"

  name           = var.name
  aws_region     = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id

  ami_id        = var.ami
  instance_type = var.instance_type

  user_data_base64  = data.template_cloudinit_config.cloud_init.rendered
  skip_health_check = var.skip_health_check

  vpc_id            = var.vpc_id
  jenkins_subnet_id = var.jenkins_subnet_id
  alb_subnet_ids    = var.alb_subnet_ids
  tenancy           = var.tenancy

  create_route53_entry = true
  hosted_zone_id       = var.hosted_zone_id
  domain_name          = var.domain_name
  acm_cert_domain_name = var.acm_ssl_certificate_domain

  is_internal_alb                             = var.is_internal_alb
  allow_incoming_http_from_cidr_blocks        = var.allow_incoming_http_from_cidr_blocks
  allow_incoming_http_from_security_group_ids = var.allow_incoming_http_from_security_group_ids

  key_pair_name                     = var.keypair_name
  allow_ssh_from_cidr_blocks        = var.allow_ssh_from_cidr_blocks
  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids

  root_block_device_volume_type = var.root_block_device_volume_type
  root_block_device_volume_size = var.root_volume_size

  ebs_volume_type      = var.jenkins_volume_type
  ebs_volume_size      = var.jenkins_volume_size
  ebs_volume_encrypted = var.jenkins_volume_encrypted
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT TO RUN ON JENKINS WHEN IT BOOTS
# This script will attach and mount the EBS volume
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "jenkins-default-cloud-init"
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
    # This is the default name tag for the server-group module Jenkins uses under the hood
    volume_name_tag = "ebs-volume-0"

    aws_region                          = data.aws_region.current.name
    device_name                         = var.jenkins_device_name
    mount_point                         = var.jenkins_mount_point
    owner                               = var.jenkins_user
    memory                              = var.memory
    log_group_name                      = var.name
    enable_ssh_grunt                    = var.enable_ssh_grunt
    enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
    ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
    ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
    external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy to Jenkins that allows ssh-grunt to make API calls to IAM to fetch IAM user and group data.
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
  role   = module.jenkins.jenkins_iam_role_id
  policy = var.external_account_ssh_grunt_role_arn == "" ? module.ssh_grunt_policies.ssh_grunt_permissions : module.ssh_grunt_policies.allow_access_to_other_accounts[0]
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE JENKINS THE PERMISSIONS IT NEEDS TO RUN BUILDS IN THIS ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "build_permissions" {
  statement {
    effect    = "Allow"
    actions   = var.build_permission_actions
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy_this_account_permissions" {
  count  = length(var.build_permission_actions) > 0 ? 1 : 0
  name   = "deploy-this-account-permissions"
  role   = module.jenkins.jenkins_iam_role_id
  policy = module.auto_deploy_iam_policies.allow_access_to_all_other_accounts
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE JENKINS PERMISSIONS TO DEPLOY IN OTHER AWS ACCOUNTS
# Add an IAM policy that allows Jenkins to assume IAM roles in other AWS accounts to do automated deployment in those
# accounts.
# ---------------------------------------------------------------------------------------------------------------------

module "auto_deploy_iam_policies" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.25.1"

  aws_account_id = data.aws_caller_identity.current.account_id

  # Jenkins is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  allow_access_to_other_account_arns = var.external_account_auto_deploy_iam_role_arns
}

resource "aws_iam_role_policy" "deploy_other_account_permissions" {
  count  = length(var.external_account_auto_deploy_iam_role_arns) > 0 ? 1 : 0
  name   = "deploy-other-accounts-permissions"
  role   = module.jenkins.jenkins_iam_role_id
  policy = module.auto_deploy_iam_policies.allow_access_to_all_other_accounts
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.18.3"

  name_prefix      = var.name

  # We set this to false so that the cloudwatch-custom-metrics-iam-policy generates the JSON for the policy, but does
  # not create a standalone IAM policy with that JSON. We'll instead add that JSON to the Jenkins IAM role.
  create_resources = false
}

resource "aws_iam_role_policy" "custom_cloudwatch_metrics" {
  count  = var.enable_cloudwatch_metrics ? 1 : 0
  name   = "custom-cloudwatch-metrics"
  role   = module.jenkins.jenkins_iam_role_id
  policy = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions_json
}

# ------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.18.3"

  name_prefix = var.name

  # We set this to false so that the cloudwatch-log-aggregation-iam-policy generates the JSON for the policy, but does
  # not create a standalone IAM policy with that JSON. We'll instead add that JSON to the Jenkins IAM role.
  create_resources = false
}

resource "aws_iam_role_policy" "cloudwatch_log_aggregation" {
  count  = var.enable_cloudwatch_log_aggregation ? 1 : 0
  name   = "cloudwatch-log-aggregation"
  role   = module.jenkins.jenkins_iam_role_id
  policy = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF JENKIN'S CPU, MEMORY, OR DISK USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.18.3"

  asg_names            = [module.jenkins.jenkins_asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

module "high_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.18.3"

  asg_names            = [module.jenkins.jenkins_asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

module "high_disk_usage_jenkins_volume_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.18.3"

  asg_names            = [module.jenkins.jenkins_asg_name]
  num_asg_names        = 1
  file_system          = var.jenkins_device_name
  mount_path           = var.jenkins_mount_point
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

module "high_disk_usage_root_volume_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.18.3"

  asg_names            = [module.jenkins.jenkins_asg_name]
  num_asg_names        = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

# ---------------------------------------------------------------------------------------------------------------------
# RUN A SCHEDULED LAMBDA FUNCTION TO PERIODICALLY BACK UP THE JENKINS SERVER
# The lambda function uses a tool called ec2-snapper to take a snapshot of the Jenkins EBS volume
# ---------------------------------------------------------------------------------------------------------------------

module "jenkins_backup" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ec2-backup?ref=v0.18.1"

  instance_name = module.jenkins.jenkins_asg_name

  backup_job_schedule_expression = var.backup_schedule_expression
  backup_job_alarm_period        = var.backup_job_alarm_period

  delete_older_than = "15d"
  require_at_least  = 15

  cloudwatch_metric_name      = var.backup_job_metric_namespace
  cloudwatch_metric_namespace = var.backup_job_metric_name

  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}