# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY ECS SERVICE
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

locals {
  # This example demonstrates creating a common base configuration across normal and canary container definitions, while also changing the canary container definition to run a different image tag 
  # This is a helpful pattern for using the canary task to verify a new release candidate
  container_definitions = {
    name : var.service_name,
    image : "nginx:1.17",
    cpu : 1024,
    memory : 256,
    essential : true
    Environment : [{ name : "TEST_ENV_VAR", value : "test-env-val" }],
    portMappings : [
      {
        "hostPort" : 80,
        "containerPort" : 80,
        "protocol" : "tcp"
      }
    ]
  }

  # Override the canary task definition to use a unique name and a newer image tag, as you might do when testing a new release tag prior to rolling it out fully
  canary_container_overrides = {
    image : "nginx:1.18"
  }
  # The resulting canary_container_definition is identical to local.container_definition, except its image version is newer and its name is unique
  canary_container_definition = merge(local.container_definitions, local.canary_container_overrides)

  canary_container_definitions = [local.canary_container_definition]
}

module "alb" {
  source = "git::git@github.com:gruntwork-io/module-load-balancer.git//modules/alb?ref=v0.14.1"

  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  alb_name         = var.service_name
  environment_name = "test"
  is_internal_alb  = false

  http_listener_ports                    = [80]
  https_listener_ports_and_ssl_certs     = []
  https_listener_ports_and_acm_ssl_certs = []
  ssl_policy                             = "ELBSecurityPolicy-TLS-1-1-2017-01"

  vpc_id         = var.vpc_id
  vpc_subnet_ids = var.subnet_ids
}

module "ecs_service" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-service?ref=v1.0.8"
  source = "../../../../modules/services/ecs-service"

  service_name     = var.service_name
  ecs_cluster_arn  = var.ecs_cluster_arn
  ecs_cluster_name = var.ecs_cluster_name

  container_definitions = [local.container_definitions]

  # An example of configuring a container definition within Terraform: 
  canary_container_definitions = local.canary_container_definitions
  # Run one canary container 
  desired_number_of_canary_tasks = 1

  use_auto_scaling = true

  desired_number_of_tasks = var.desired_number_of_tasks
  max_number_of_tasks     = var.max_number_of_tasks
  min_number_of_tasks     = var.min_number_of_tasks

  ecs_node_port_mappings = var.ecs_node_port_mappings

  dependencies = [module.alb.alb_arn]
  # Load balancer configuration
  elb_target_groups = {
    alb = {
      name                  = var.service_name
      container_name        = local.container_definitions.name
      container_port        = 80
      protocol              = "HTTP"
      health_check_protocol = "HTTP"
    }
  }

  elb_target_group_vpc_id = var.vpc_id

  # Cloudwatch configuration 
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period

  alarm_sns_topic_arns = [aws_sns_topic.ecs-alerts.arn]
}

# EXAMPLE OF A PATH-BASED LISTENER RULE
# Path-based Listener Rules are used when you wish to route all requests received by the ALB that match a certain
# "path" pattern to a given ECS Service. This is useful if you have one service that should receive all requests sent
# to /api and another service that receives requests sent to /customers.
resource "aws_alb_listener_rule" "path_based_example" {
  # Get the Listener ARN associated with port 80 on the ALB
  # In other words, this ALB has a Listener that listens for incoming traffic on port 80. That Listener has a unique
  # Amazon Resource Name (ARN), which we must pass to this rule so it knows which ALB Listener to "attach" to. Fortunately,
  # Our ALB module outputs values like http_listener_arns, https_listener_non_acm_cert_arns, and https_listener_acm_cert_arns
  # so that we can easily look up the ARN by the port number.
  listener_arn = module.alb.http_listener_arns["80"]

  priority = 100

  action {
    type             = "forward"
    target_group_arn = module.ecs_service.target_group_arns["alb"]
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
# Demonstrates adding a security group rule allowing access to port 80 on the container instances. These instances run the ecs task
# which also binds to port 80 allowing them to serve as web hosts.
resource "aws_security_group_rule" "ecs_cluster_instances_webserver" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = var.ecs_instance_security_group_id
}
Demonstrates adding a security group rule allowing access to port 22 on the container instance. You would want to do this if you need to debug your container instances by ssh'ing into them
resource "aws_security_group_rule" "ecs_cluster_instance_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = var.ecs_instance_security_group_id
}

# Create an SNS topic to receive ecs-related alerts when defined service thresholds are breached
resource "aws_sns_topic" "ecs-alerts" {
  name = "ecs-alerts-topic"
}

data "aws_caller_identity" "current" {}
