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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-core-services?ref=v0.62.0"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/services/eks-core-services"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "route53_public" {
  config_path = "${get_terragrunt_dir()}/../../../../_global/route53-public"

  mock_outputs = {
    public_hosted_zone_map = { "refarch-sbox-dev-mock.com" = "mock-zone-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                 = "mock-vpc-id"
    private_app_subnet_ids = ["mock-subnet-id-private-app", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "aurora" {
  config_path = "${get_terragrunt_dir()}/../../data-stores/aurora"

  mock_outputs = {
    primary_endpoint = "database"
    port             = 5432
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}



dependency "eks_cluster" {
  config_path = "${get_terragrunt_dir()}/../eks-cluster"

  mock_outputs = {
    eks_cluster_name                       = "eks-cluster"
    eks_default_fargate_execution_role_arn = "arn:aws:::iam"
    eks_iam_role_for_service_accounts_config = {
      openid_connect_provider_arn = "arn:aws:::openid"
      openid_connect_provider_url = "https://openid"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "eks_applications_namespace" {
  config_path = "${get_terragrunt_dir()}/../eks-applications-namespace"

  mock_outputs = {
    namespace_name = "applications"
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

  # Extract the account_name and account_role for easy access
  account_name = local.account_vars.locals.account_name
  account_role = local.account_vars.locals.account_role

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  aws_region                               = local.region_vars.locals.aws_region
  vpc_id                                   = dependency.vpc.outputs.vpc_id
  eks_cluster_name                         = dependency.eks_cluster.outputs.eks_cluster_name
  eks_iam_role_for_service_accounts_config = dependency.eks_cluster.outputs.eks_iam_role_for_service_accounts_config

  # Fargate configuration
  # We will schedule everything we can on Fargate. Each of these pods use an IP address on the worker nodes, so it helps
  # to schedule them off the worker nodes.
  schedule_alb_ingress_controller_on_fargate = true
  schedule_external_dns_on_fargate           = true
  schedule_cluster_autoscaler_on_fargate     = true
  worker_vpc_subnet_ids                      = dependency.vpc.outputs.private_app_subnet_ids
  pod_execution_iam_role_arn                 = dependency.eks_cluster.outputs.eks_default_fargate_execution_role_arn

  # The route53-public module creates AWS hosted zones which are containers for DNS records for a given domain.
  # Passing this list of route53 hosted zone IDs will allow external-dns to create records into all zones managed by terraform
  external_dns_route53_hosted_zone_id_filters = values(dependency.route53_public.outputs.public_hosted_zone_map)

  # We create service DNS mappings for data stores so that we can use the service discovery mechanism baked into
  # Kubernetes to reach the relevant services.
  service_dns_mappings = {
    database = {
      target_dns  = dependency.aurora.outputs.primary_endpoint
      target_port = tostring(dependency.aurora.outputs.port)
      namespace   = dependency.eks_applications_namespace.outputs.namespace_name
    }
  }
}