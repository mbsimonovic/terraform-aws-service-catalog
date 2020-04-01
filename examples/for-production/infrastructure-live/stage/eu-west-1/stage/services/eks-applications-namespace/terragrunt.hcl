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
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-namespace?ref=master"
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
dependency "eks_cluster" {
  config_path = "../eks-cluster"
}

# We set prevent destroy here to prevent accidentally deleting your company's data in case of overly ambitious use
# of destroy or destroy-all. If you really want to run destroy on this module, remove this flag.
prevent_destroy = true

# Generate a Kubernetes provider configuration for authenticating against the EKS cluster.
generate "k8s_provider" {
  path      = "k8s_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster" "cluster" {
  name  = "${dependency.eks_cluster.outputs.eks_cluster_name}"
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name  = "${dependency.eks_cluster.outputs.eks_cluster_name}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = "applications"
}
