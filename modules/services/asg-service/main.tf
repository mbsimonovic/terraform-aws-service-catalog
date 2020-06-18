# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A SERVICE IN AN AUTO SCALING GROUP WITH AN ALB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  required_providers {
    aws = "~> 2.6"
  }

  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

module "asg" {
  source = "git::git@github.com:gruntwork-io/module-asg.git//modules/asg-rolling-deploy?ref=v0.9.0"

  launch_configuration_name = aws_launch_configuration.launch_configuration.name
  vpc_subnet_ids            = var.subnet_ids
  target_group_arns         = [aws_alb_target_group.service.arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  min_elb_capacity = var.min_elb_capacity
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "launch_configuration" {
  name_prefix          = "${var.name}-"
  image_id             = var.ami
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = var.key_pair_name
  security_groups      = [aws_security_group.lc_security_group.id]
  user_data            = var.user_data

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
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

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
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

# Inbound HTTP from the ALB
resource "aws_security_group_rule" "ingress_alb" {
  type              = "ingress"
  from_port         = var.server_port
  to_port           = var.server_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
//  security_groups   = var.alb_security_groups
  security_group_id = aws_security_group.lc_security_group.id
}

//resource "aws_security_group_rule" "ingress_ssh" {
//  type              = "ingress"
//  from_port         = 22
//  to_port           = 22
//  protocol          = "tcp"
//  cidr_blocks       = ["0.0.0.0/0"]
//  security_group_id = aws_security_group.lc_security_group.id
//}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE AND POLICY THAT ARE ATTACHED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.name
  role = aws_iam_role.instance_role.name

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
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
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy to each EC2 Instance that allows ssh-grunt to make API calls to IAM to fetch IAM user and group
# data.
# ---------------------------------------------------------------------------------------------------------------------

module "iam_policies" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.32.0"

  aws_account_id = data.aws_caller_identity.current.account_id

  # ASG is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  allow_access_to_other_account_arns = var.external_account_auto_deploy_iam_role_arns
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  count  = length(var.external_account_auto_deploy_iam_role_arns) > 0 ? 1 : 0
  name   = "deploy-other-accounts-permissions"
  role   = aws_iam_role.instance_role.id
  policy = module.iam_policies.ssh_grunt_permissions // from or to ?
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TARGET GROUP AND LISTENER RULE TO RECEIVE TRAFFIC FROM THE ALB FOR CERTAIN PATHS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "service" {
  name     = var.name
  port     = var.server_port
  protocol = var.health_check_protocol
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
    protocol            = var.health_check_protocol
    port                = "traffic-port"
    path                = var.health_check_path
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ROUTING RULES FOR THIS SERVICE
# Below, we configure the ALB to send requests that come in on certain ports (the listener_arn) and certain paths or
# domain names (the condition block) to the Target Group that contains this ASG service.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener_rule" "paths_to_route_to_this_service" {
  count = length(var.alb_listener_rule_configs)

  listener_arn = var.alb_listener_arn
  priority     = var.alb_listener_rule_configs[count.index]["priority"]

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = [var.alb_listener_rule_configs[count.index]["path"]]
    }
  }
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
    name                   = var.original_alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_metrics

  name_prefix = var.name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_metrics_policy" {
  count = var.enable_cloudwatch_metrics ? 1 : 0

  name       = "attach-cloudwatch-metrics-policy"
  roles      = [aws_iam_role.instance_role.id]
  policy_arn = module.cloudwatch_metrics.cloudwatch_metrics_policy_arn
}

# ------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_log_aggregation

  name_prefix = var.name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_log_aggregation_policy" {
  count = var.enable_cloudwatch_log_aggregation ? 1 : 0

  name = "attach-cloudwatch-log-aggregation-policy"

  roles      = [aws_iam_role.instance_role.id]
  policy_arn = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE SERVICE'S CPU, MEMORY, OR DISK USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "asg_high_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

module "asg_high_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

module "asg_high_disk_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD A ROUTE 53 HEALTHCHECK THAT TRIGGERS AN ALARM IF THE DOMAIN NAME IS UNRESPONSIVE
# Note: Route 53 sends all of its CloudWatch metrics to us-east-1, so the health check, alarm, and SNS topic must ALL
# live in us-east-1 as well! See https://github.com/hashicorp/terraform/issues/7371 for details.
# ---------------------------------------------------------------------------------------------------------------------

module "route53_health_check" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/route53-health-check-alarms?ref=v0.21.2"

  create_resources = var.enable_route53_health_check

  domain                         = var.domain_name
  alarm_sns_topic_arns_us_east_1 = var.alarm_sns_topic_arns_us_east_1

  path = var.health_check_path
  type = var.health_check_protocol
  port = var.server_port

  failure_threshold = 2
  request_interval  = 30
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DATA SOURCES
# These resources must already exist.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Grab the current region as a data source so the operator only needs to set it on the provider
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
