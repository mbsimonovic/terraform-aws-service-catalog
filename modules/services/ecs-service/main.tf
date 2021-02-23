# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS SERVICE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
# CREATE AN ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_service" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-ecs.git//modules/ecs-service?ref=v0.25.1"

  service_name     = var.service_name
  environment_name = var.service_name
  ecs_cluster_arn  = var.ecs_cluster_arn

  launch_type                     = var.launch_type
  capacity_provider_strategy      = var.capacity_provider_strategy
  placement_strategy_type         = var.placement_strategy_type
  placement_strategy_field        = var.placement_strategy_field
  placement_constraint_type       = var.placement_constraint_type
  placement_constraint_expression = var.placement_constraint_expression

  ecs_task_container_definitions = local.container_definitions
  desired_number_of_tasks        = var.desired_number_of_tasks

  ecs_task_definition_canary            = local.has_canary ? local.canary_container_definitions : null
  desired_number_of_canary_tasks_to_run = local.has_canary ? var.desired_number_of_canary_tasks : 0

  use_auto_scaling    = var.use_auto_scaling
  min_number_of_tasks = var.use_auto_scaling ? var.min_number_of_tasks : null
  max_number_of_tasks = var.use_auto_scaling ? var.max_number_of_tasks : null

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  clb_name           = var.clb_name
  clb_container_name = var.clb_container_name
  clb_container_port = var.clb_container_port

  elb_target_groups       = var.elb_target_groups
  elb_target_group_vpc_id = var.elb_target_group_vpc_id

  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  health_check_enabled              = var.health_check_enabled
  health_check_interval             = var.health_check_interval
  health_check_path                 = var.health_check_target_group_path
  health_check_port                 = var.health_check_port
  health_check_timeout              = var.health_check_timeout
  health_check_healthy_threshold    = var.health_check_healthy_threshold
  health_check_unhealthy_threshold  = var.health_check_unhealthy_threshold
  health_check_matcher              = var.health_check_matcher

  enable_ecs_deployment_check      = var.enable_ecs_deployment_check
  deployment_check_timeout_seconds = var.deployment_check_timeout_seconds
  deployment_check_loglevel        = var.deployment_check_loglevel

  service_tags         = var.service_tags
  task_definition_tags = var.task_definition_tags
  propagate_tags       = var.propagate_tags

  dependencies = var.dependencies
}

# Update the ECS Node Security Group to allow the ECS Service to be accessed directly from an ECS Node (versus only from the ELB).
resource "aws_security_group_rule" "custom_permissions" {
  for_each = var.expose_ecs_service_to_other_ecs_nodes ? var.ecs_node_port_mappings : {}

  type      = "ingress"
  from_port = each.value
  to_port   = each.value
  protocol  = "tcp"

  source_security_group_id = var.ecs_instance_security_group_id
  security_group_id        = var.ecs_instance_security_group_id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CONTAINER DEFINITION THAT SPECIFIES WHAT DOCKER CONTAINERS TO RUN AND THE RESOURCES THEY NEED
# ---------------------------------------------------------------------------------------------------------------------

locals {

  container_definitions = jsonencode(var.container_definitions)

  has_canary                   = var.canary_container_definitions != null ? true : false
  canary_container_definitions = local.has_canary ? jsonencode(var.canary_container_definitions) : null

  cloudwatch_log_group_name = var.cloudwatch_log_group_name != null ? var.cloudwatch_log_group_name : var.service_name
  cloudwatch_log_prefix     = "ecs-service"


}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM PERMISSIONS FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "service_policy" {
  count  = var.iam_role_name != "" && var.iam_policy != null ? 1 : 0
  name   = "${var.iam_role_name}Policy"
  role   = module.ecs_service.ecs_task_iam_role_name
  policy = data.aws_iam_policy_document.service_policy[0].json
}

data "aws_iam_policy_document" "service_policy" {
  count = var.iam_role_name != "" && var.iam_policy != null ? 1 : 0

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
  count  = var.iam_role_name != "" && var.secrets_access != null ? 1 : 0
  name   = "${var.iam_role_name}SecretsAccessPolicy"
  role   = module.ecs_service.ecs_task_iam_role_name
  policy = data.aws_iam_policy_document.secrets_access_policy_document[0].json
}

data "aws_iam_policy_document" "secrets_access_policy_document" {
  count = var.iam_role_name != "" && var.secrets_access != null ? 1 : 0

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
  for_each = var.iam_role_name != "" ? { for secret in var.secrets_access : secret => secret } : {}
  arn      = each.value
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM POLICY AND EXECUTION ROLE TO ALLOW ECS TASK TO MAKE CLOUDWATCH REQUESTS AND PULL IMAGES FROM ECR
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.service_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json

  # IAM objects take time to propagate. This leads to subtle eventual consistency bugs where the ECS task cannot be
  # created because the IAM role does not exist. We add a 15 second wait here to give the IAM role a chance to propagate
  # within AWS.
  provisioner "local-exec" {
    command = "echo 'Sleeping for 15 seconds to wait for IAM role to be created'; sleep 15"
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name   = "${var.service_name}-task-execution-policy"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy_document.json
  role   = aws_iam_role.ecs_task_execution_role.name
}

data "aws_iam_policy_document" "ecs_task_execution_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  dynamic "statement" {
    # The contents of the for each list does not matter here, as the only purpose is to determine whether or not to
    # include this statement block.
    for_each = length(var.secrets_manager_arns) > 0 ? ["include_secrets_manager_permissions"] : []

    content {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.secrets_manager_arns
    }
  }

  dynamic "statement" {
    for_each = compact([var.secrets_manager_kms_key_arn])

    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [var.secrets_manager_kms_key_arn]
    }
  }
}

# Define the Assume Role IAM Policy Document for ECS to assume these roles
data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ROUTING RULES FOR THIS SERVICE
# Below, we configure the ALB to send requests that come in on certain ports (the listener_arn) and certain paths or
# domain names (the condition block) to the Target Group that contains this ASG service.
# ---------------------------------------------------------------------------------------------------------------------
module "listener_rules" {
  source                 = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/lb-listener-rules?ref=v0.21.0"
  default_listener_arns  = var.default_listener_arns
  default_listener_ports = var.default_listener_ports

  default_forward_target_group_arns = flatten([
    for key, target_group_arn in module.ecs_service.target_group_arns : {
      arn = target_group_arn
    }
  ])

  forward_rules        = var.forward_rules
  redirect_rules       = var.redirect_rules
  fixed_response_rules = var.fixed_response_rules
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS TO ALERT OPERATORS TO IMPORTANT ISSUES
# ---------------------------------------------------------------------------------------------------------------------

# Add CloudWatch Alarms that go off if the ECS Service's CPU or Memory usage gets too high.
module "ecs_service_cpu_memory_alarms" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ecs-service-alarms?ref=v0.24.1"

  ecs_service_name     = var.service_name
  ecs_cluster_name     = var.ecs_cluster_name
  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "metric_widget_ecs_service_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.24.1"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}

module "metric_widget_ecs_service_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.24.1"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} MemoryUtilization"

  metrics = [
    ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.service_name],
  ]
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
  alarm_sns_topic_arns_us_east_1 = var.alarm_sns_topic_arns_us_east_1

  alarm_configs = {
    default = {
      domain = var.domain_name
      path   = var.health_check_path
      type   = var.health_check_protocol
      port   = var.server_port

      failure_threshold = 2
      request_interval  = 30
    }
  }
}
