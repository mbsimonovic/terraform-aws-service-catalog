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
# LAUNCH JENKINS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # We tag all jenkins resources with a static, known tag, so that all jenkins deployments (even when the name changes)
  # can be logically grouped as one. For example, this allows you to logically group all snapshots together under one
  # backup policy by using this tag as opposed to the name, which may change when employing a blue-green rollout strategy.
  server_group_tags = {
    service = "jenkins"
  }
}

module "jenkins" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-ci.git//modules/jenkins-server?ref=v0.40.2"

  name       = var.name
  aws_region = data.aws_region.current.name

  custom_tags = merge(local.server_group_tags, var.custom_tags)

  ami_id        = module.ec2_baseline.existing_ami
  instance_type = var.instance_type

  user_data_base64  = module.ec2_baseline.cloud_init_rendered
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
  redirect_http_to_https                      = true

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
  iam_role_name                       = module.jenkins.jenkins_iam_role_id
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  enable_asg_cloudwatch_alarms        = var.enable_cloudwatch_alarms
  asg_names                           = [module.jenkins.jenkins_asg_name]
  num_asg_names                       = 1
  alarms_sns_topic_arn                = var.alarms_sns_topic_arn
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters
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
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  ip_lockdown_users = compact([
    var.default_user,
    var.jenkins_user,
  ])
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
      # This is the default name tag for the server-group module Jenkins uses under the hood
      volume_name_tag = "ebs-volume-0"

      aws_region                          = data.aws_region.current.name
      device_name                         = var.jenkins_device_name
      mount_point                         = var.jenkins_mount_point
      owner                               = var.jenkins_user
      memory                              = var.memory
      log_group_name                      = var.name
      enable_ssh_grunt                    = var.enable_ssh_grunt
      enable_fail2ban                     = false
      enable_ip_lockdown                  = var.enable_ip_lockdown
      enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
      ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
      ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
      external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
      ip_lockdown_users                   = local.ip_lockdown_users_bash_array
    },
  ))
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE JENKINS PERMISSIONS TO DECRYPT THE ENCRYPTED EBS VOLUME
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "kms_cmk" {
  count = var.ebs_kms_key_arn != null ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = [local.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "ebs_kms_cmk_permissions" {
  count  = var.ebs_kms_key_arn != null ? 1 : 0
  name   = "ebs-kms-cmk-permissions"
  role   = module.jenkins.jenkins_iam_role_id
  policy = data.aws_iam_policy_document.kms_cmk[0].json
}

# ----------------------------------------------------------------------------------------------------------------------
# TRANSLATE THE KMS KEY ALIAS TO ID
# If the provided key ARN is an alias, we swap it for the key ID which is necessary for the permissions to be granted
# successfully.
# ----------------------------------------------------------------------------------------------------------------------

data "aws_kms_key" "by_loose_id" {
  count  = var.ebs_kms_key_arn != null && var.ebs_kms_key_arn_is_alias ? 1 : 0
  key_id = var.ebs_kms_key_arn
}

locals {
  kms_key_arn = (
    length(data.aws_kms_key.by_loose_id) > 0
    ? data.aws_kms_key.by_loose_id[0].arn
    : var.ebs_kms_key_arn
  )
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
  policy = data.aws_iam_policy_document.build_permissions.json
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE JENKINS PERMISSIONS TO DEPLOY IN OTHER AWS ACCOUNTS
# Add an IAM policy that allows Jenkins to assume IAM roles in other AWS accounts to do automated deployment in those
# accounts.
# ---------------------------------------------------------------------------------------------------------------------

module "auto_deploy_iam_policies" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/iam-policies?ref=v0.58.0"

  aws_account_id = data.aws_caller_identity.current.account_id

  # Jenkins is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  allow_access_to_other_account_arns = { "jenkins" = var.external_account_auto_deploy_iam_role_arns }
}

resource "aws_iam_role_policy" "deploy_other_account_permissions" {
  count  = length(var.external_account_auto_deploy_iam_role_arns) > 0 ? 1 : 0
  name   = "deploy-other-accounts-permissions"
  role   = module.jenkins.jenkins_iam_role_id
  policy = module.auto_deploy_iam_policies.allow_access_to_all_other_accounts
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF the JENKINS DATA VOLUME DISK USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "high_disk_usage_jenkins_volume_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.30.5"

  asg_names            = [module.jenkins.jenkins_asg_name]
  num_asg_names        = 1
  file_system          = var.jenkins_device_name
  mount_path           = var.jenkins_mount_point
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
  create_resources     = var.enable_cloudwatch_alarms
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE BACKUP POLICIES FOR JENKINS SERVER
#
# Here we show two different ways to configure backups for your jenkins server: AWS Data Lifecycle Management Policies,
# and scheduled Lambda functions. There are tradeoffs to consider between the two approaches. Refer to the
# documentation for more information.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# AWS Data Lifecycle Management Policies Backup
# ---------------------------------------------------------------------------------------------------------------------
module "jenkins_backup_dlm" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-server.git//modules/ec2-backup?ref=v0.13.8"
  count  = var.backup_using_dlm ? 1 : 0

  target_tags = local.server_group_tags

  dlm_role_name                 = "${var.name}-dlm-role"
  schedule_name                 = var.dlm_backup_job_schedule_name
  interval                      = var.dlm_backup_job_schedule_interval
  times                         = var.dlm_backup_job_schedule_times
  number_of_snapshots_to_retain = var.dlm_backup_job_schedule_number_of_snapshots_to_retain
}

# ---------------------------------------------------------------------------------------------------------------------
# Scheduled lambda function to periodically back up the jenkins server.
# The lambda function uses a tool called ec2-snapper to take a snapshot of the Jenkins EBS volume.
# ---------------------------------------------------------------------------------------------------------------------

module "jenkins_backup" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-ci.git//modules/ec2-backup?ref=v0.40.2"
  count  = var.backup_using_lambda ? 1 : 0

  instance_name = module.jenkins.jenkins_asg_name

  backup_job_schedule_expression = var.backup_job_schedule_expression
  backup_job_alarm_period        = var.backup_job_alarm_period

  delete_older_than = "15d"
  require_at_least  = 15

  cloudwatch_metric_name      = var.backup_job_metric_name
  cloudwatch_metric_namespace = var.backup_job_metric_namespace

  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
