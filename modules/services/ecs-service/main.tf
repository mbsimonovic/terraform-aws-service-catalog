# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS SERVICE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
# CREATE AN ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_service" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-ecs.git//modules/ecs-service?ref=v0.31.8"

  service_name    = var.service_name
  ecs_cluster_arn = var.ecs_cluster_arn

  launch_type                      = var.launch_type
  capacity_provider_strategy       = var.capacity_provider_strategy
  placement_strategy_type          = var.placement_strategy_type
  placement_strategy_field         = var.placement_strategy_field
  placement_constraint_type        = var.placement_constraint_type
  placement_constraint_expression  = var.placement_constraint_expression
  ecs_task_definition_network_mode = var.network_mode
  ecs_service_network_configuration = (
    var.network_mode == "awsvpc"
    ? {
      subnets          = var.network_configuration.subnets
      security_groups  = concat(aws_security_group.service.*.id, var.network_configuration.additional_security_group_ids)
      assign_public_ip = var.network_configuration.assign_public_ip
    }
    : null
  )
  task_cpu    = var.task_cpu
  task_memory = var.task_memory

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
  health_check_path                 = var.health_check_path
  health_check_port                 = var.health_check_port
  health_check_timeout              = var.health_check_timeout
  health_check_healthy_threshold    = var.health_check_healthy_threshold
  health_check_unhealthy_threshold  = var.health_check_unhealthy_threshold
  health_check_matcher              = var.health_check_matcher

  enable_execute_command = var.enable_execute_command

  enable_ecs_deployment_check      = var.enable_ecs_deployment_check
  deployment_check_timeout_seconds = var.deployment_check_timeout_seconds
  deployment_check_loglevel        = var.deployment_check_loglevel

  service_tags         = var.service_tags
  task_definition_tags = var.task_definition_tags
  propagate_tags       = var.propagate_tags

  custom_iam_role_name_prefix       = var.custom_iam_role_name_prefix
  custom_task_execution_name_prefix = var.custom_task_execution_iam_role_name_prefix
  custom_ecs_service_role_name      = var.custom_ecs_service_role_name

  volumes     = var.volumes
  efs_volumes = var.efs_volumes

  deployment_circuit_breaker = {
    enable   = var.deployment_circuit_breaker_enabled
    rollback = var.deployment_circuit_breaker_enabled && var.deployment_circuit_breaker_rollback
  }

  proxy_configuration = var.proxy_configuration_container_name != null && var.proxy_configuration_properties != null ? {
    type           = "APPMESH"
    container_name = var.proxy_configuration_container_name
    properties     = var.proxy_configuration_properties
  } : null

  dependencies = var.dependencies
}

# Create a Security group if the user provides dynamic rules for the awsvpc network mode.
resource "aws_security_group" "service" {
  count = (
    # Ideally we can concat these two conditions using &&, but in Terraform && does not short circuit, so we can't
    # combine them as when network_mode is not awsvpc, network_configuration is likely null.
    var.network_mode == "awsvpc"
    ? (
      length(var.network_configuration.security_group_rules) > 0
      ? 1 : 0
    )
    : 0
  )

  name   = var.service_name
  vpc_id = var.network_configuration.vpc_id
}
resource "aws_security_group_rule" "dynamic" {
  for_each                 = var.network_mode == "awsvpc" ? var.network_configuration.security_group_rules : {}
  security_group_id        = length(aws_security_group.service) > 0 ? aws_security_group.service[0].id : null
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  cidr_blocks              = each.value.cidr_blocks
}

# Update the ECS Node Security Group to allow the ECS Service to be accessed directly from an ECS Node (versus only from the ELB).
resource "aws_security_group_rule" "custom_permissions" {
  for_each = var.launch_type == "EC2" && var.expose_ecs_service_to_other_ecs_nodes ? var.ecs_node_port_mappings : {}

  type      = "ingress"
  from_port = each.value
  to_port   = each.value
  protocol  = "tcp"

  source_security_group_id = var.ecs_instance_security_group_id
  security_group_id        = var.ecs_instance_security_group_id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CLOUDWATCH LOG GROUP FOR HOLDING TASK LOGS IF REQUESTED
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "eks_cluster" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = var.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CONTAINER DEFINITION THAT SPECIFIES WHAT DOCKER CONTAINERS TO RUN AND THE RESOURCES THEY NEED
# ---------------------------------------------------------------------------------------------------------------------

locals {
  container_definitions = jsonencode(var.container_definitions)

  has_canary                   = var.canary_container_definitions != null ? true : false
  canary_container_definitions = local.has_canary ? jsonencode(var.canary_container_definitions) : null
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM PERMISSIONS FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "service_policy" {
  count  = var.iam_policy != null ? 1 : 0
  name   = "${local.iam_policy_name_prefix}Policy"
  role   = module.ecs_service.ecs_task_iam_role_name
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
  name   = "${local.iam_policy_name_prefix}SecretsAccessPolicy"
  role   = module.ecs_service.ecs_task_iam_role_name
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

locals {
  iam_policy_name_prefix = var.custom_iam_policy_prefix == null ? var.service_name : var.custom_iam_policy_prefix
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM POLICY TO ALLOW ECS TASK TO ACCESS SECRETS AND BIND TO ROLE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  count  = local.task_execution_role_needs_secrets_access ? 1 : 0
  name   = "${var.service_name}-task-execution-policy"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy_document[0].json
  role   = module.ecs_service.ecs_task_execution_iam_role_name
}

data "aws_iam_policy_document" "ecs_task_execution_policy_document" {
  count = local.task_execution_role_needs_secrets_access ? 1 : 0

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

locals {
  task_execution_role_needs_secrets_access = length(var.secrets_manager_arns) > 0 || var.secrets_manager_kms_key_arn != null
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ROUTING RULES FOR THIS SERVICE
# Below, we configure the ALB to send requests that come in on certain ports (the listener_arn) and certain paths or
# domain names (the condition block) to the Target Group that contains this ASG service.
# ---------------------------------------------------------------------------------------------------------------------
module "listener_rules" {
  source                 = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/lb-listener-rules?ref=v0.27.3"
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/ecs-service-alarms?ref=v0.30.5"

  ecs_service_name     = var.service_name
  ecs_cluster_name     = var.ecs_cluster_name
  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "metric_widget_ecs_service_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}

module "metric_widget_ecs_service_memory_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/route53-health-check-alarms?ref=v0.30.5"

  create_resources                 = var.enable_route53_health_check
  alarm_sns_topic_arns_us_east_1   = var.alarm_sns_topic_arns_us_east_1
  provider_role_arn                = var.route53_health_check_provider_role_arn
  provider_external_id             = var.route53_health_check_provider_external_id
  provider_session_name            = var.route53_health_check_provider_session_name
  provider_profile                 = var.route53_health_check_provider_profile
  provider_shared_credentials_file = var.route53_health_check_provider_shared_credentials_file

  alarm_configs = {
    default = {
      domain = var.domain_name
      path   = var.route53_health_check_path
      type   = var.route53_health_check_protocol
      port   = var.route53_health_check_port

      failure_threshold = 2
      request_interval  = 30
    }
  }
}
