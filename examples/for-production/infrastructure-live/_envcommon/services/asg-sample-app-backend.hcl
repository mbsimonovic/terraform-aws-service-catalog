# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common override configuration for asg-sample-app in backend mode. This configuration will be merged
# into the environment configuration via an include block.
# NOTE: This configuration MUST be included with _envcommon/asg-sample-app.hcl
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

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
  # Automatically load common account and region variables.
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_name = local.account_vars.locals.account_name
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  aws_region   = local.region_vars.locals.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above. This
# defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = "sample-app-backend"

  listener_arns                         = dependency.alb_internal.outputs.listener_arns
  allow_inbound_from_security_group_ids = [dependency.alb_internal.outputs.alb_security_group_id]

  # -------------------------------------------------------------------------------------------------------------
  # Private common inputs
  # The following are common data (like locals) that can be used to construct the final input. We take advantage
  # of the fact that Terraform ignores extraneous variables defined in Terragrunt to make this work. We use _ to
  # denote these variables to avoid the chance of accidentally setting a real variable. We define these here
  # instead of using locals because locals can not reference dependencies.
  # -------------------------------------------------------------------------------------------------------------

  # Specify base variables for user-data template. These should be merged with environment specific variables in the
  # child terragrunt configuration, and passed into the user-data template for rendering.
  _base_user_data_template_vars = {
    app_name               = "backend"
    environment_name       = local.account_name
    log_group_name         = "${local.account_name}-sample-app-backend"
    http_port              = 8080
    https_port             = 8443
    secrets_manager_region = local.aws_region
    services_config        = ""
    database_config = yamlencode({
      database = {
        host                  = dependency.aurora.outputs.primary_endpoint
        maxConnectionPoolSize = 10
      }
    })
    cache_config = yamlencode({
      cache = {
        engine = "memcached"
        host   = dependency.memcached.outputs.configuration_endpoint
        port   = tostring(dependency.memcached.outputs.cache_port)
      }
    })
  }
}
