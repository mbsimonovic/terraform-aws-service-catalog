
# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/ecs-service?ref=v0.34.1"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id = "vpc-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "ecs_cluster" {
  config_path = "${get_terragrunt_dir()}/../ecs-cluster"

  mock_outputs = {
    ecs_cluster_arn  = "some-ecs-cluster-arn"
    ecs_cluster_name = "ecs-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}





dependency "sns" {
  config_path = "${get_terragrunt_dir()}/../../../_regional/sns-topic"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:123456789012:mytopic-NZJ5JSMVGFIE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "alb" {
  config_path = "${get_terragrunt_dir()}/../../networking/alb"

  mock_outputs = {
    listener_arns = {
      80  = "mock-listener"
      443 = "mock-listener"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}





# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name for easy access
  account_name = local.account_vars.locals.account_name

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  service_name            = "sample-app-frontend"
  tls_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:345678901234:secret:TLSFrontEndSecretsManagerArn-abcd1234"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # -------------------------------------------------------------------------------------------------------------------
  # Cluster and container configuration
  # -------------------------------------------------------------------------------------------------------------------

  service_name     = local.service_name
  ecs_cluster_name = dependency.ecs_cluster.outputs.ecs_cluster_name
  ecs_cluster_arn  = dependency.ecs_cluster.outputs.ecs_cluster_arn

  # Configure the container ports to be exposed using the same port numbers on the worker nodes that it is running on.
  ecs_node_port_mappings = {
    "8080" = 8080
    "8443" = 8443
  }

  # The Container definitions of the ECS service. Refer to the AWS docs for supported options:
  # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
  container_definitions = [{
    name      = local.service_name
    image     = "gruntwork/aws-sample-app:v0.0.2"
    cpu       = 512
    memory    = 256
    essential = true
    environment = [
      {
        name  = "CONFIG_APP_NAME"
        value = "frontend"
      },
      {
        name  = "CONFIG_APP_ENVIRONMENT_NAME"
        value = local.account_name
      },
      {
        name  = "CONFIG_SECRETS_DIR"
        value = "/mnt/secrets"
      },
      {
        name  = "CONFIG_SECRETS_SECRETS_MANAGER_TLS_ID"
        value = local.tls_secrets_manager_arn
      },
      {
        name  = "CONFIG_SECRETS_SECRETS_MANAGER_REGION"
        value = local.aws_region
      },
      {
        name = "CONFIG_SERVICES"
        value = jsonencode({
          backend = {
            host     = "gruntwork-sample-app-backend.${local.account_vars.locals.domain_name.name}"
            port     = 443
            protocol = "https"
          }
        })
      },
    ]
    # The container ports that should be exposed from this container.
    portMappings = [
      {
        "containerPort" = 8080
        "protocol"      = "tcp"
      },
      {
        "containerPort" = 8443
        "protocol"      = "tcp"
      }
    ],
    # We mount a tmpfs volume at /mnt/secrets. This is expected by the Gruntwork Sample App so that secrets that are
    # pulled down from Secrets Manager are only stored in memory, and not in disk.
    linuxParameters = {
      tmpfs = [{
        containerPath = "/mnt/secrets"
        size          = 10
      }],
    },
    # Configure log aggregation from the ECS service to stream to CloudWatch logs.
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = "/${local.account_name}/ecs/${local.service_name}"
        awslogs-region        = local.aws_region
        awslogs-stream-prefix = "ecs"
        awslogs-create-group  = "true"
      }
    },
  }]

  use_auto_scaling = false

  # --------------------------------------------------------------------------------------------------------------------
  # ALB configuration
  # We configure Target Groups for the ECS service so that the ALBs can route to the ECS tasks that are deployed on each
  # node by the service.
  # --------------------------------------------------------------------------------------------------------------------

  elb_target_groups = {
    alb = {
      name                  = local.service_name
      container_name        = local.service_name
      container_port        = 8443
      protocol              = "HTTPS"
      health_check_protocol = "HTTPS"
    }
  }
  elb_target_group_deregistration_delay = 60
  elb_target_group_vpc_id               = dependency.vpc.outputs.vpc_id
  default_listener_arns                 = dependency.alb.outputs.listener_arns
  default_listener_ports                = ["443"]

  # Configure the ALB listener rules to forward HTTPS traffic to the ECS service.
  forward_rules = {
    "default" = {
      listener_arns = [
        dependency.alb.outputs.listener_arns["443"],
      ]
      port          = 443
      path_patterns = ["/*"]
    }
  }

  # Configure the ALB listener rules to redirect HTTP traffic to HTTPS
  redirect_rules = {
    "http-to-https" = {
      listener_ports = [80]
      status_code    = "HTTP_301"
      port           = 443
      protocol       = "HTTPS"
      path_patterns  = ["/*"]
    }
  }

  # -------------------------------------------------------------------------------------------------------------
  # IAM permissions
  # Grant the necessary IAM permissions to the ECS service so that it can read the Secrets Manager entries.
  # -------------------------------------------------------------------------------------------------------------

  custom_iam_policy_prefix = local.service_name
  secrets_access = [
    local.tls_secrets_manager_arn,
  ]

  # -------------------------------------------------------------------------------------------------------------
  # CloudWatch Alarms
  # -------------------------------------------------------------------------------------------------------------

  alarm_sns_topic_arns = [dependency.sns.outputs.topic_arn]
}