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
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/eks-core-services?ref=master"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# When using the terragrunt xxx-all commands (e.g., apply-all, plan-all), deploy these dependencies before this module
dependencies {
  paths = ["../../../../_global/account-baseline"]
}

# Pull in outputs from these modules to compute inputs. These modules will also be added to the dependency list for
# xxx-all commands.
dependency "vpc" {
  config_path = "../../networking/vpc"
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
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

  # Configuration for external-dns
  # TODO: We'd normally use a dependency block to pull in the hosted zone ID, but we haven't converted the route 53
  # modules to the new service catalog format yet, so for now, we just hard-code the ID.
  external_dns_route53_hosted_zone_id_filters = ["Z2AJ7S3R6G9UYJ"]
}
