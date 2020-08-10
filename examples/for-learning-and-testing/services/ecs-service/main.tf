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
    name        = var.service_name
    image       = "nginx:1.17"
    cpu         = 1024,
    memory      = 256,
    essential   = true
    Environment = [{ name : "TEST_NAME", value : "TEST_VALUE" }]
    portMappings = [
      {
        "hostPort"      = 80
        "containerPort" = 80
        "protocol"      = "tcp"
      }
    ]
  }

  # Override the canary task definition to use a unique name and a newer image tag, as you might do when testing a new release tag prior to rolling it out fully
  canary_container_overrides = {
    image = "nginx:1.18"
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

  http_listener_ports = []
  https_listener_ports_and_acm_ssl_certs = [
    {
      port            = 443
      tls_domain_name = "*.gruntwork.in"
    }
  ]
  https_listener_ports_and_acm_ssl_certs_num = 1

  https_listener_ports_and_ssl_certs = []
  ssl_policy                         = "ELBSecurityPolicy-TLS-1-1-2017-01"

  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = tolist(data.aws_subnet_ids.default.ids)
}

module "ecs_service" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/ecs-service?ref=v1.0.8"
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

  # Open the security group for the EC2 instances backing the ECS cluster on ports 22 (ssh) and 80 (web)
  expose_ecs_service_to_other_ecs_nodes = true
  ecs_node_port_mappings                = var.ecs_node_port_mappings
  ecs_instance_security_group_id        = var.ecs_instance_security_group_id

  # Ensure the load balancer is provisioned before the ecs service is created 
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

  elb_target_group_vpc_id = data.aws_vpc.default.id

  # Load balancer listener rules
  default_listener_arns  = module.alb.listener_arns
  default_listener_ports = ["443"]

  forward_rules = {
    "test" = {
      priority      = 120
      port          = 443
      path_patterns = ["/*"]
    }
  }

  # Create a route 53 entry and point it at the load balancer 
  create_route53_entry        = true
  domain_name                 = var.domain_name
  hosted_zone_id              = var.hosted_zone_id
  enable_route53_health_check = true

  health_check_protocol = "HTTPS"

  original_lb_dns_name = module.alb.alb_dns_name
  lb_hosted_zone_id    = module.alb.alb_hosted_zone_id

  alarm_sns_topic_arns = [aws_sns_topic.ecs-alerts.arn]
}

# Create a security group rule allowing traffic from the load balancer to reach
# the target groups on the EC2 instances backing the EC2 cluster
resource "aws_security_group_rule" "loadbalancer_to_ec2" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = var.ecs_instance_security_group_id
  # Only allow access to the EC2 container instances from the Application Load Balancer
  source_security_group_id = module.alb.alb_security_group_id
}

# Create an SNS topic to receive ecs-related alerts when defined service thresholds are breached
resource "aws_sns_topic" "ecs-alerts" {
  name = "ecs-alerts-topic"
}

# Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

# Look up the default VPC's subnets
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_caller_identity" "current" {}
