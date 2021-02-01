# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A SERVICE IN AN AUTO SCALING GROUP WITH AN ALB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.68"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

module "asg" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-asg.git//modules/asg-rolling-deploy?ref=v0.11.1"

  launch_configuration_name = aws_launch_configuration.launch_configuration.name
  vpc_subnet_ids            = var.subnet_ids
  target_group_arns         = local.listeners_target_group_array

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  min_elb_capacity = var.min_elb_capacity

  termination_policies = var.termination_policies
  load_balancers       = var.load_balancers

  use_elb_health_checks = var.use_elb_health_checks
  enabled_metrics       = var.enabled_metrics

  health_check_grace_period = var.health_check_grace_period
  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  tag_asg_id_key = var.tag_asg_id_key
  custom_tags    = var.custom_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "launch_configuration" {
  name_prefix          = "${var.name}-"
  image_id             = module.ec2_baseline.existing_ami
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = var.key_pair_name
  security_groups      = [aws_security_group.lc_security_group.id]
  user_data_base64     = module.ec2_baseline.cloud_init_rendered

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "lc_security_group" {
  name        = "${var.name}-lc"
  description = "Security group for the ${var.name} launch configuration"
  vpc_id      = var.vpc_id
}

# Outbound everything
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lc_security_group.id
}

resource "aws_security_group_rule" "ingress_server_ports_cidr_blocks" {
  for_each = length(var.allow_inbound_from_cidr_blocks) == 0 ? {} : var.server_ports

  type              = "ingress"
  from_port         = each.value.server_port
  to_port           = each.value.server_port
  protocol          = "tcp"
  cidr_blocks       = var.allow_inbound_from_cidr_blocks
  security_group_id = aws_security_group.lc_security_group.id
}

resource "aws_security_group_rule" "ingress_server_ports_security_group_ids" {
  count = length(local.server_ports_array) * length(var.allow_inbound_from_security_group_ids)

  type                     = "ingress"
  from_port                = local.ingress_security_ids[count.index].port
  to_port                  = local.ingress_security_ids[count.index].port
  protocol                 = "tcp"
  source_security_group_id = local.ingress_security_ids[count.index].security_group_id
  security_group_id        = aws_security_group.lc_security_group.id
}

resource "aws_security_group_rule" "ingress_ssh_cidr_blocks" {
  count = length(var.allow_ssh_from_cidr_blocks) == 0 ? 0 : 1

  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allow_ssh_from_cidr_blocks
  security_group_id = aws_security_group.lc_security_group.id
}

resource "aws_security_group_rule" "ingress_ssh_security_group_ids" {
  count = length(var.allow_ssh_security_group_ids)

  type                     = "ingress"
  from_port                = var.ssh_port
  to_port                  = var.ssh_port
  protocol                 = "tcp"
  source_security_group_id = element(var.allow_ssh_security_group_ids, count.index)
  security_group_id        = aws_security_group.lc_security_group.id
}

# ---------------------------------------------------------------------------------------------------------------------
# BASE RESOURCES
# Includes resources common to all EC2 instances in the Service Catalog, including permissions for ssh-grunt, CloudWatch Logs aggregation, CloudWatch metrics, and CloudWatch alarms
# ---------------------------------------------------------------------------------------------------------------------

module "ec2_baseline" {
  source = "../../base/ec2-baseline"

  name                                = var.name
  enable_ssh_grunt                    = local.enable_ssh_grunt
  external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
  enable_cloudwatch_log_aggregation   = var.enable_cloudwatch_log_aggregation
  enable_cloudwatch_metrics           = var.enable_cloudwatch_metrics
  iam_role_name                       = aws_iam_role.instance_role.name
  asg_names                           = [module.asg.asg_name]
  num_asg_names                       = 1
  cloud_init_parts                    = local.cloud_init_parts
  ami                                 = var.ami
  ami_filters                         = var.ami_filters
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE AND POLICY THAT ARE ATTACHED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.name
  role = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CUSTOM IAM PERMISSIONS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "service_policy" {
  count  = var.iam_policy != null ? 1 : 0
  name   = "${var.name}Policy"
  role   = aws_iam_role.instance_role.name
  policy = data.aws_iam_policy_document.service_policy[0].json
}

data "aws_iam_policy_document" "service_policy" {
  count = var.iam_policy != null ? 1 : 0

  dynamic "statement" {
    for_each = var.iam_policy == null ? {} : var.iam_policy

    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "secrets_access_policy" {
  count  = length(var.secrets_access) > 0 ? 1 : 0
  name   = "${var.name}SecretsAccessPolicy"
  role   = aws_iam_role.instance_role.name
  policy = data.aws_iam_policy_document.secrets_access_policy_document[0].json
}

data "aws_iam_policy_document" "secrets_access_policy_document" {
  count = length(var.secrets_access) > 0 ? 1 : 0

  statement {
    sid       = "SecretsAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for secret in data.aws_secretsmanager_secret.secrets_arn_exchange : secret.arn]
  }
}

# This allows the user to pass either the full ARN of a Secrets Manager secret (including the randomly generated
# suffix) or the ARN without the random suffix. The data source will find the full ARN for use in the IAM policy.
data "aws_secretsmanager_secret" "secrets_arn_exchange" {
  for_each = { for secret in var.secrets_access : secret => secret }
  arn      = each.value
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TARGET GROUP THAT WILL RECEIVE TRAFFIC FROM THE ALB FOR CERTAIN PATHS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "service" {
  for_each = local.target_groups

  name     = "${var.name}-${each.key}"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  dynamic "health_check" {
    for_each = each.value.enable_lb_health_check ? ["once"] : []

    content {
      port     = "traffic-port"
      protocol = each.value.protocol
      path     = each.value.path

      healthy_threshold   = each.value.healthy_threshold
      unhealthy_threshold = each.value.unhealthy_threshold
      interval            = each.value.interval
      timeout             = each.value.timeout
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ROUTING RULES FOR THIS SERVICE
# Below, we configure the ALB to send requests that come in on certain ports (the listener_arn) and certain paths or
# domain names (the condition block) to the Target Group that contains this ASG service.
# ---------------------------------------------------------------------------------------------------------------------

module "listener_rules" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/lb-listener-rules?ref=v0.21.0"

  default_listener_arns  = var.listener_arns
  default_listener_ports = var.listener_ports

  default_forward_target_group_arns = concat(
    var.default_forward_target_group_arns,
    local.listeners_target_group
  )

  forward_rules        = var.forward_listener_rules
  redirect_rules       = var.redirect_listener_rules
  fixed_response_rules = var.fixed_response_listener_rules

}

# ------------------------------------------------------------------------------
# CREATE A DNS RECORD USING ROUTE 53
# ------------------------------------------------------------------------------

resource "aws_route53_record" "service" {
  count = var.create_route53_entry ? 1 : 0

  zone_id = var.hosted_zone_id

  name = var.domain_name
  type = "A"

  alias {
    name                   = var.original_lb_dns_name
    zone_id                = var.lb_hosted_zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD A ROUTE 53 HEALTHCHECK THAT TRIGGERS AN ALARM IF THE DOMAIN NAME IS UNRESPONSIVE
# Note: Route 53 sends all of its CloudWatch metrics to us-east-1, so the health check, alarm, and SNS topic must ALL
# live in us-east-1 as well! See https://github.com/hashicorp/terraform/issues/7371 for details.
# ---------------------------------------------------------------------------------------------------------------------

module "route53_health_check" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/route53-health-check-alarms?ref=v0.24.1"

  create_resources               = var.enable_route53_health_check
  alarm_configs                  = local.route53_alarm_configurations
  alarm_sns_topic_arns_us_east_1 = var.alarm_sns_topic_arns_us_east_1
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE ECS CLUSTER
# This script will configure each instance so it registers in the right ECS cluster and authenticates to the proper
# Docker registry.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default cloud init script for this module
  cloud_init = {
    filename     = "asg-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = local.base_user_data
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)

  ip_lockdown_users = compact(flatten([
    var.default_user,
    var.metadata_users,
    # User used to push cloudwatch metrics from the server. This should only be included in the ip-lockdown list if
    # reporting cloudwatch metrics is enabled.
    var.enable_cloudwatch_metrics ? "cwmonitoring" : ""
  ]))
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
      enable_ssh_grunt                    = local.enable_ssh_grunt
      enable_fail2ban                     = var.enable_fail2ban
      enable_ip_lockdown                  = var.enable_ip_lockdown
      ssh_grunt_iam_group                 = var.ssh_grunt_iam_group
      ssh_grunt_iam_group_sudo            = var.ssh_grunt_iam_group_sudo
      external_account_ssh_grunt_role_arn = var.external_account_ssh_grunt_role_arn
      ip_lockdown_users                   = local.ip_lockdown_users_bash_array
    },
  )

  enable_ssh_grunt = var.ssh_grunt_iam_group == "" && var.ssh_grunt_iam_group_sudo == "" ? false : true

  listeners_target_group = flatten([
    for target_group in aws_alb_target_group.service : {
      arn = target_group.arn
    }
  ])

  listeners_target_group_array = [
    for target_group in aws_alb_target_group.service :
    target_group.arn
  ]

  route53_alarm_configurations = {
    for key, item in var.server_ports :
    key => {
      domain = var.domain_name
      port   = item.server_port
      path   = lookup(item, "health_check_path", null)
      tags   = lookup(item, "tags", {})

      type              = lookup(item, "r53_health_check_type", null)
      failure_threshold = lookup(item, "r53_health_check_failure_threshold", 2)
      request_interval  = lookup(item, "r53_health_check_request_interval", 30)
    }
  }

  target_groups = {
    for key, item in var.server_ports :
    key => {
      port     = item.server_port
      path     = lookup(item, "health_check_path", null)
      protocol = lookup(item, "protocol", "HTTP")
      tags     = lookup(item, "tags", {})

      enable_lb_health_check = lookup(item, "enable_lb_health_check", true)
      healthy_threshold      = lookup(item, "lb_healthy_threshold", 2)
      unhealthy_threshold    = lookup(item, "lb_unhealthy_threshold", 2)
      interval               = lookup(item, "lb_request_interval", 30)
      timeout                = lookup(item, "lb_timeout", 10)
    }
  }

  server_ports_array = [
    for key, item in var.server_ports :
    item.server_port
  ]

  ingress_security_ids = [
    for item in setproduct(local.server_ports_array, var.allow_inbound_from_security_group_ids) :
    {
      port              = item[0]
      security_group_id = item[1]
    }
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DATA SOURCES
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Grab the current region as a data source so the operator only needs to set it on the provider
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
