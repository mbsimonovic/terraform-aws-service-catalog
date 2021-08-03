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
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/asg-service?ref=v0.54.0"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/services/asg-service"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                         = "vpc-abcd1234"
    private_app_subnet_ids         = ["subnet-abcd1234", "subnet-bcd1234a", ]
    private_app_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "network_bastion" {
  config_path = "${get_terragrunt_dir()}/../../networking/openvpn-server"

  mock_outputs = {
    security_group_id = "sg-abcd1234"
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


dependency "aurora" {
  config_path = "${get_terragrunt_dir()}/../../data-stores/aurora"

  mock_outputs = {
    primary_endpoint = "rds"
    port             = 5432
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "alb_internal" {
  config_path = "${get_terragrunt_dir()}/../../networking/alb-internal"

  mock_outputs = {
    alb_security_group_id = "sg-abcd1234"
    listener_arns = {
      80  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
      443 = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}


dependency "memcached" {
  config_path = "${get_terragrunt_dir()}/../../data-stores/memcached"

  mock_outputs = {
    configuration_endpoint = "cache"
    cache_port             = 6379
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

  external_account_ssh_grunt_role_arn = "arn:aws:iam::${local.common_vars.locals.accounts.security}:role/allow-ssh-grunt-access-from-other-accounts"

  # Specify the AMI version here so that it can be overridden in a CI/CD pipeline.
  ami_version = "v0.0.2"

}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name = "sample-app-backend"
  ami  = ""
  ami_filters = {
    owners = [local.common_vars.locals.accounts.shared]
    filters = [
      {
        name   = "name"
        values = ["aws-sample-app-${local.ami_version}-*"]
      },
    ]
  }
  instance_type    = "t3.medium"
  key_pair_name    = "${local.account_name}-asg-v1"
  min_size         = 2
  max_size         = 3
  min_elb_capacity = 1
  desired_capacity = 2

  external_account_ssh_grunt_role_arn = "${local.external_account_ssh_grunt_role_arn}"

  # Deploy the ASG into the app VPC, inside the private app tier.
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_app_subnet_ids


  listener_arns                         = dependency.alb_internal.outputs.listener_arns
  allow_inbound_from_security_group_ids = [dependency.alb_internal.outputs.alb_security_group_id]
  allow_ssh_security_group_ids          = [dependency.network_bastion.outputs.security_group_id]
  allow_ssh_from_cidr_blocks            = []

  listener_ports = [
    80,
    443,
  ]

  forward_listener_rules = {
    "root-route" = {
      path_patterns = ["/*"]
    }
  }

  server_ports = {
    http = {
      server_port       = 8080
      health_check_path = "/health"
    }
    https = {
      server_port       = 8443
      protocol          = "HTTPS"
      health_check_path = "/health"
    }
  }

  # Allow the application user to access the EC2 metadata which is locked down by default using the Gruntwork ip-lockdown
  # script from the terraform-aws-security module
  metadata_users = ["app"]

  # Grant access to read the Secrets Manager secrets
  secrets_access = [
    "arn:aws:secretsmanager:us-west-2:567890123456:secret:RDSDBConfig-abcd1234",
    "arn:aws:secretsmanager:us-west-2:567890123456:secret:TLSBackEndSecretsManagerArn-abcd1234",
  ]

  cloud_init_parts = {
    "gruntwork-sample-app" = {
      filename     = "gruntwork-sample-app"
      content_type = "text/x-shellscript"
      content = templatefile("sample-app-user-data.sh", {
        app_name                            = "backend"
        environment_name                    = local.account_name
        log_group_name                      = "${local.account_name}-sample-app-backend"
        external_account_ssh_grunt_role_arn = local.external_account_ssh_grunt_role_arn
        http_port                           = 8080
        https_port                          = 8443
        secrets_manager_region              = local.aws_region
        db_config_secrets_manager_arn       = "arn:aws:secretsmanager:us-west-2:567890123456:secret:RDSDBConfig-abcd1234"
        tls_config_secrets_manager_arn      = "arn:aws:secretsmanager:us-west-2:567890123456:secret:TLSBackEndSecretsManagerArn-abcd1234"
        secrets_manager_config = yamlencode({
          "secretsManager" : {
            "region" : local.aws_region,
            "dbId" : "arn:aws:secretsmanager:us-west-2:567890123456:secret:RDSDBConfig-abcd1234",
            "tlsId" : "arn:aws:secretsmanager:us-west-2:567890123456:secret:TLSBackEndSecretsManagerArn-abcd1234",
          }
        })
        database_config = yamlencode({
          "database" : {
            "host" : dependency.aurora.outputs.primary_endpoint,
            "maxConnectionPoolSize" : 10,
          }
        })
        cache_config = yamlencode({
          "cache" : {
            "engine" : "memcached",
            "host" : dependency.memcached.outputs.configuration_endpoint,
            "port" : tostring(dependency.memcached.outputs.cache_port),
          }
        })
        services_config = ""

      })
    }
  }
}