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
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-service?ref=v0.20.4"

  service_name     = var.service_name
  environment_name = var.service_name
  ecs_cluster_arn  = var.ecs_cluster_arn

  # TODO - fix these definitions to contain all definition json 
  ecs_task_container_definitions = aws_ecs_task_definition.service.0.container_definitions
  ecs_task_definition_canary     = local.has_canary ? aws_ecs_task_definition.canary.0.container_definitions : null

  desired_number_of_canary_tasks_to_run = local.has_canary ? var.desired_number_of_canary_tasks_to_run : 0

  desired_number_of_tasks = var.desired_number_of_tasks

  # Tell the ECS Service that we are using auto scaling, so the desired_number_of_tasks setting is only used to control
  # the initial number of Tasks, and auto scaling is used to determine the size after that.
  use_auto_scaling    = var.use_auto_scaling
  min_number_of_tasks = var.use_auto_scaling ? var.min_number_of_tasks : null
  max_number_of_tasks = var.use_auto_scaling ? var.max_number_of_tasks : null

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
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
resource "aws_ecs_task_definition" "service" {
  for_each = var.container_images

  family             = "${var.service_name}-${each.key}"
  task_role_arn      = aws_iam_role.ecs_task.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode       = "awsvpc"
  cpu                = var.cpu
  memory             = var.memory

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${each.value.docker_image}:${each.value.docker_tag}"
      essential = true
      secrets = [
        for env_var, arn in each.value.secrets_manager_arns :
        {
          name      = env_var
          valueFrom = arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = local.cloudwatch_log_group_name
          awslogs-stream-prefix = "${local.cloudwatch_log_prefix}"
        }
      }
    },
  ])
}

resource "aws_ecs_task_definition" "canary" {
  for_each = var.canary_images

  family             = "${var.service_name}-${each.key}"
  task_role_arn      = aws_iam_role.ecs_task.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode       = "awsvpc"
  cpu                = var.cpu
  memory             = var.memory

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${each.value.docker_image}:${each.value.docker_tag}"
      essential = true
      secrets = [
        for env_var, arn in each.value.secrets_manager_arns :
        {
          name      = env_var
          valueFrom = arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = local.cloudwatch_log_group_name
          awslogs-stream-prefix = "${local.cloudwatch_log_prefix}"
        }
      }
    },
  ])
}

# Convert the maps of ports to the container definition JSON format.
data "template_file" "port_mappings" {
  count    = length(var.ecs_node_port_mappings)
  template = <<EOF
{
  "containerPort": ${var.ecs_node_port_mappings[element(keys(var.ecs_node_port_mappings), count.index)]},
  "hostPort": ${element(keys(var.ecs_node_port_mappings), count.index)},
  "protocol": "tcp"
}
EOF
}

locals {

  secret_manager_arns = flatten([
    for name, container in var.container_images :
    [for env_var, secret_arn in container.secrets_manager_arns : secret_arn]
  ])


  has_canary = length(var.canary_images) > 0 ? true : false

  # Create default map of env vars in the JSON format used by ECS container definitions.
  #
  # NOTE: if you add a default env var, make sure to update the count in data.template_file.all_env_vars!!!
  default_env_vars = map(
    var.aws_region_env_var_name, var.aws_region,
    var.db_url_env_var_name, var.db_primary_endpoint,
  )

  # Merge the default env vars with any extra env vars passed in by the user into a single map
  all_env_vars = merge(local.default_env_vars, var.extra_env_vars)

  cloudwatch_log_group_name = var.cloudwatch_log_group_name != null ? var.cloudwatch_log_group_name : var.service_name
  cloudwatch_log_prefix     = "ecs-service"
}

# Convert the env vars into a JSON format used by ECS container definitions.
data "template_file" "all_env_vars" {
  # Terraform does not allow us to depend on modules, data sources, or any other dynamic data in the count parameter,
  # so we have to manually add the number of env vars in var.extra_env_vars and local.default_env_vars.
  count    = var.num_extra_env_vars + 2
  template = <<EOF
{
  "name": "${element(keys(local.all_env_vars), count.index)}",
  "value": "${lookup(local.all_env_vars, element(keys(local.all_env_vars), count.index))}"
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM PERMISSIONS FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

# Give this ECS Service access to the KMS Master Key so it can use it to decrypt secrets in config files.
resource "aws_iam_role_policy" "access_kms_master_key" {
  name   = "access-kms-master-key"
  role   = module.ecs_service.ecs_task_iam_role_name
  policy = data.aws_iam_policy_document.access_kms_master_key.json
}

# Create an IAM Policy for acessing the KMS Master Key
data "aws_iam_policy_document" "access_kms_master_key" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_master_key_arn]
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
  alarm_sns_topic_arns = [var.alarm_sns_topic_arn]

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

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE AUTO SCALING OF THIS ECS SERVICE'S CONTAINERS
# Note that Auto Scaling of the ECS Cluster's EC2 Instances is handled spearately.
# ---------------------------------------------------------------------------------------------------------------------

# Create an Auto Scaling Policy to scale the number of ECS Tasks up in response to load.
resource "aws_appautoscaling_policy" "scale_out" {
  count = var.use_auto_scaling ? 1 : 0
  name  = "${var.service_name}-scale-out"

  service_namespace = "${var.service_name}-namespace"

  resource_id = "service/${var.ecs_cluster_name}/${var.service_name}"

  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown        = 300
  }

  # NOTE: due to a Terraform bug, this depends_on does not actually help, and it's possible the auto scaling target has
  # not been created when Terraform tries to create this auto scaling policy. As a result, you get an error along the
  # lines of "Error putting scaling policy: ObjectNotFoundException: No scalable target registered for service
  # namespace..." Wait a few seconds, re-run `terraform apply`, and the erorr should go away. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10737
  depends_on = [module.ecs_service]
}

# Create an Auto Scaling Policy to scale the number of ECS Tasks down in response to load.
resource "aws_appautoscaling_policy" "scale_in" {
  count       = var.use_auto_scaling ? 1 : 0
  name        = "${var.service_name}-scale-in"
  resource_id = "service/${var.ecs_cluster_name}/${var.service_name}"

  service_namespace  = "${var.service_name}-namespace"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    cooldown        = 300
  }

  # NOTE: due to a Terraform bug, this depends_on does not actually help, and it's possible the auto scaling target has
  # not been created when Terraform tries to create this auto scaling policy. As a result, you get an error along the
  # lines of "Error putting scaling policy: ObjectNotFoundException: No scalable target registered for service
  # namespace..." Wait a few seconds, re-run `terraform apply`, and the erorr should go away. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10737
  depends_on = [module.ecs_service]
}

# Create a CloudWatch Alarm to trigger our Auto Scaling Policies if CPU Utilization gets too high.
resource "aws_cloudwatch_metric_alarm" "high_cpu_usage" {
  count             = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name        = "${var.service_name}-high-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too high"
  namespace         = "AWS/ECS"
  metric_name       = "CPUUtilization"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Average"
  threshold           = "90"
  unit                = "Percent"
  alarm_actions       = [var.use_auto_scaling ? aws_appautoscaling_policy.scale_out.0.arn : null]
}

# Create a CloudWatch Alarm to trigger our Auto Scaling Policies if CPU Utilization gets sufficiently low.
resource "aws_cloudwatch_metric_alarm" "low_cpu_usage" {
  count             = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name        = "${var.service_name}-low-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too low"
  namespace         = "AWS/ECS"
  metric_name       = "CPUUtilization"

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  unit                = "Percent"
  alarm_actions       = [var.use_auto_scaling ? aws_appautoscaling_policy.scale_in.0.arn : null]
}
