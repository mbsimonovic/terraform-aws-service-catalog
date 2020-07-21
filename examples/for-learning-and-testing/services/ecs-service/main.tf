# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY ECS SERVICE
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "application" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-service?ref=v1.0.8"
  source = "../../../../modules/services/ecs-service"

  service_name     = var.service_name
  ecs_cluster_arn  = var.ecs_cluster_arn
  ecs_cluster_name = var.ecs_cluster_name

  container_definitions        = var.container_definitions
  canary_container_definitions = var.canary_container_definitions

  use_auto_scaling = true

  desired_number_of_tasks = var.desired_number_of_tasks
  max_number_of_tasks     = var.max_number_of_tasks
  min_number_of_tasks     = var.min_number_of_tasks

  # Canary task configuration
  canary_version                 = var.canary_version
  desired_number_of_canary_tasks = var.desired_number_of_canary_tasks

  ecs_node_port_mappings = var.ecs_node_port_mappings

  # Cloudwatch configuration 
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period

  kms_master_key_arn   = var.kms_master_key_arn
  alarm_sns_topic_arns = [aws_sns_topic.ecs-alerts.arn]
}

resource "aws_sns_topic" "ecs-alerts" {
  name = "ecs-alerts-topic"
}
