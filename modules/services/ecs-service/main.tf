# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS SERVICE
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
# CREATE AN ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_service" {
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-service?ref=canary-task-unique-family-name"

  service_name     = var.service_name
  environment_name = var.service_name
  ecs_cluster_arn  = var.ecs_cluster_arn

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

  enable_ecs_deployment_check      = var.enable_ecs_deployment_check
  deployment_check_timeout_seconds = var.deployment_check_timeout_seconds
  deployment_check_loglevel        = var.deployment_check_loglevel

  dependencies = var.dependencies
}

# Update the ECS Node Security Group to allow the ECS Service to be accessed directly from an ECS Node (versus only from the ELB).
resource "aws_security_group_rule" "custom_permissions" {
  count = var.expose_ecs_service_to_other_ecs_nodes ? length(var.ecs_node_port_mappings) : 0

  type      = "ingress"
  from_port = element(values(var.ecs_node_port_mappings), count.index)
  to_port   = element(values(var.ecs_node_port_mappings), count.index)
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

  secret_manager_arns = flatten([
    for name, container in var.secret_manager_arns :
    [for env_var, secret_arn in lookup(container, "secrets_manager_arns", []) : secret_arn]
  ])

  cloudwatch_log_group_name = var.cloudwatch_log_group_name != null ? var.cloudwatch_log_group_name : var.service_name
  cloudwatch_log_prefix     = "ecs-service"
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM PERMISSIONS FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "service_policy" {
  count  = var.iam_role_name != "" ? 1 : 0
  name   = "${var.iam_role_name}Policy"
  role   = aws_iam_role.ecs_task
  policy = data.aws_iam_policy_document.service_policy[0].json
}

data "aws_iam_policy_document" "service_policy" {
  count = var.iam_role_name != "" ? 1 : 0

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

# Create the ECS Task IAM Role
resource "aws_iam_role" "ecs_task" {
  name               = "${var.service_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json

  # IAM objects take time to propagate. This leads to subtle eventual consistency bugs where the ECS task cannot be
  # created because the IAM role does not exist. We add a 15 second wait here to give the IAM role a chance to propagate
  # within AWS.
  provisioner "local-exec" {
    command = "echo 'Sleeping for 15 seconds to wait for IAM role to be created'; sleep 15"
  }
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
  name   = "${var.service_name}-task-excution-policy"
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
    for_each = length(local.secret_manager_arns) > 0 ? ["include_secrets_manager_permissions"] : []

    content {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.secret_manager_arns
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
# ADD CLOUDWATCH ALARMS TO ALERT OPERATORS TO IMPORTANT ISSUES
# ---------------------------------------------------------------------------------------------------------------------

# Add CloudWatch Alarms that go off if the ECS Service's CPU or Memory usage gets too high.
module "ecs_service_cpu_memory_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ecs-service-alarms?ref=v0.21.2"

  ecs_service_name     = var.service_name
  ecs_cluster_name     = var.ecs_cluster_name
  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "metric_widget_ecs_service_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.21.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}

module "metric_widget_ecs_service_memory_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.21.2"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} MemoryUtilization"

  metrics = [
    ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}
