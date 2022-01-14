# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for services/asg-sample-app. The common variables for each environment to
# deploy services/asg-sample-app are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/asg-service?ref=v0.70.0"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/services/asg-service"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

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
  config_path = "${get_terragrunt_dir()}/../../networking/bastion-host"

  mock_outputs = {
    bastion_host_security_group_id = "sg-abcd1234"
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

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/asg-service"

  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name and account_role for easy access
  account_name = local.account_vars.locals.account_name
  account_role = local.account_vars.locals.account_role

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  external_account_ssh_grunt_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids.security}:role/allow-ssh-grunt-access-from-other-accounts"

  # Define the path to the user data script template. This will be used by the child config to render the specific
  # user-data script to use for that environment.
  user_data_template_path = "${get_parent_terragrunt_dir()}/asg-sample-app-user-data.sh"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  instance_type    = "t3.micro"
  key_pair_name    = "asg-app-cluster-admin-v1"
  min_size         = 1
  max_size         = 1
  min_elb_capacity = 1
  desired_capacity = 1

  external_account_ssh_grunt_role_arn = "${local.external_account_ssh_grunt_role_arn}"

  # Deploy the ASG into the app VPC, inside the private app tier.
  vpc_id                       = dependency.vpc.outputs.vpc_id
  subnet_ids                   = dependency.vpc.outputs.private_app_subnet_ids
  allow_ssh_security_group_ids = [dependency.network_bastion.outputs.bastion_host_security_group_id]

  allow_ssh_from_cidr_blocks = []

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
}