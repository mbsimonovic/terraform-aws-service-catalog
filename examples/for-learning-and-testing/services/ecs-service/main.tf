# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY SERVICE ON KUBERNETES USING THE K8S-SERVICE HELM CHART
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "application" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-service?ref=v1.0.8"
  source = "../../../../modules/services/ecs-service"

  cpu                               = var.cpu
  aws_region                        = var.aws_region
  service_name                      = var.service_name
  desired_number_of_tasks           = var.desired_number_of_tasks
  max_number_of_tasks               = var.max_number_of_tasks
  canary_version                    = var.canary_version
  ecs_node_port_mappings            = var.ecs_node_port_mappings
  vpc_env_var_name                  = var.vpc_env_var_name
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  desired_number_of_canary_tasks    = var.desired_number_of_canary_tasks
  high_memory_utilization_period    = var.high_memory_utilization_period
  min_number_of_tasks               = var.min_number_of_tasks
  image                             = var.image
  image_version                     = var.image_version
  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  memory                            = var.memory
  alarm_sns_topic_arn               = var.alarm_sns_topic_arn
  kms_master_key_arn                = var.kms_master_key_arn
  db_primary_endpoint               = var.db_primary_endpoint
  ecs_instance_security_group_id    = var.ecs_instance_security_group_id
  ecs_cluster_arn                   = var.ecs_cluster_arn
  ecs_cluster_name                  = var.ecs_cluster_name
  container_images                  = var.container_images
}

