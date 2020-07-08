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
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/eks-core-services?ref=v1.0.8"
  source = "../../../../../../../../modules//services/eks-core-services"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Pull in outputs from these modules to compute inputs. These modules will also be added to the dependency list for
# xxx-all commands.
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    vpc_id                 = "mock-vpc-id"
    private_app_subnet_ids = ["mock-subnet-id-priv-app"]
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"

  mock_outputs = {
    eks_cluster_name                       = "eks-cluster"
    eks_default_fargate_execution_role_arn = "arn:aws:::iam"
    eks_iam_role_for_service_accounts_config = {
      openid_connect_provider_arn = "arn:aws:::openid"
      openid_connect_provider_url = "https://openid"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "rds" {
  config_path = "../../data-stores/rds"

  mock_outputs = {
    primary_host = "database_host"
    port         = 5432
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "aurora" {
  config_path = "../../data-stores/aurora"

  mock_outputs = {
    primary_host = "database_host"
    port         = 5432
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "applications_namespace" {
  config_path = "../eks-applications-namespace"
}

# Generate a Kubernetes provider configuration for authenticating against the EKS cluster.
generate "k8s_helm" {
  path      = "k8s_helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile(
    find_in_parent_folders("provider_k8s_helm_for_eks.template.hcl"),
    { eks_cluster_name = dependency.eks_cluster.outputs.eks_cluster_name },
  )
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
  # The route53-public module creates AWS hosted zones which are containers for DNS records for a given domain. 
  # Passing this list of route53 hosted zone IDs will allow external-dns to create records into all zones managed by terraform 
  external_dns_route53_hosted_zone_domain_filters = [local.common_vars.locals.domain_names.prod]
  # Configure services for routing to databases
  service_dns_mappings = {
    rds = {
      target_dns  = dependency.rds.outputs.primary_host
      target_port = dependency.rds.outputs.port
      namespace   = "applications"
    }
    aurora = {
      target_dns  = dependency.aurora.outputs.primary_host
      target_port = dependency.aurora.outputs.port
      namespace   = "applications"
    }
  }
}
