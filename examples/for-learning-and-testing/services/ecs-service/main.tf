# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY ECS SERVICE
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

locals {
  # This exmaple demonstrates creating a common base configuration across normal and canary container definitions, while also changing the canary container definition to run a different image tag 
  # This is a helpful pattern for using the canary task to verify a new release candidate
  container_definition = {
    name : "test",
    image : "nginx:1.17",
    cpu : 1024,
    memory : 256,
    essential : true
    Environment : [{ name : "TEST_ENV_VAR", value : "test-env-val" }],
    "portMappings" : [
      {
        "hostPort" : 80,
        "containerPort" : 80,
        "protocol" : "tcp"
      }
    ]
  }

  # Override the canary task definition to use a unique name and a newer image tag, as you might do when testing a new release tag prior to rolling it out fully
  canary_container_base = {
    name : "test-canary",
    image : "nginx:1.18"
  }
  # The resulting canary_container_definition is identical to local.container_definition, except its image version is newer and its name is unique
  canary_container_definition = merge(local.container_definition, local.canary_container_base)

  container_definitions        = [local.container_definition]
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

  container_definitions = local.container_definitions

  # An example of configuring a container definition within Terraform: 
  canary_container_definitions = local.canary_container_definitions
  # Run one canary container 
  desired_number_of_canary_tasks = 0

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
      container_name        = local.container_definition.name
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

# EXAMPLE OF A HOST-BASED LISTENER RULE
# Host-based Listener Rules are used when you wish to have a single ALB handle requests for both foo.acme.com and
# bar.acme.com. Using a host-based routing rule, the ALB can route each inbound request to the desired Target Group.
resource "aws_alb_listener_rule" "host_based_example" {
  # Get the Listener ARN associated with port 80 on the ALB
  # In other words, this ALB has a Listener that listens for incoming traffic on port 80. That Listener has a unique
  # Amazon Resource Name (ARN), which we must pass to this rule so it knows which ALB Listener to "attach" to. Fortunately,
  # Our ALB module outputs values like http_listener_arns, https_listener_non_acm_cert_arns, and https_listener_acm_cert_arns
  # so that we can easily look up the ARN by the port number.
  listener_arn = module.alb.http_listener_arns["80"]

  priority = 95

  action {
    type             = "forward"
    target_group_arn = module.ecs_service.target_group_arns["alb"]
  }

  condition {
    host_header {
      values = ["*.${module.alb.alb_dns_name}"]
    }
  }
}

resource "aws_security_group_rule" "ecs_cluster_instances_webserver" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = var.ecs_instance_security_group_id
}

# Create an SNS topic to receive ecs-related alerts when defined service thresholds are breached
resource "aws_sns_topic" "ecs-alerts" {
  name = "ecs-alerts-topic"
}

# Create a security group that allows SSH access to the EC2 instances hosting the ECS containers (container instances)
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh to container instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_caller_identity" "current" {}
