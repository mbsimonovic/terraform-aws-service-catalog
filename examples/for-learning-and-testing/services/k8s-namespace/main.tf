# ----------------------------------------------------------------------------------------------------------------------
# PROVISION A NAMESPACE WITH DEFAULT RBAC ROLES
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  # Skip all checks if not using eks auth, as they are unnecessary.
  skip_credentials_validation = var.kubeconfig_auth_type != "eks"
  skip_get_ec2_platforms      = var.kubeconfig_auth_type != "eks"
  skip_region_validation      = var.kubeconfig_auth_type != "eks"
  skip_requesting_account_id  = var.kubeconfig_auth_type != "eks"
  skip_metadata_api_check     = var.kubeconfig_auth_type != "eks"
}

module "namespace" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-namespace?ref=v1.0.8"
  source = "../../../../modules/services/k8s-namespace"

  name                        = var.name
  kubeconfig_auth_type        = var.kubeconfig_auth_type
  kubeconfig_eks_cluster_name = var.kubeconfig_eks_cluster_name
  kubeconfig_path             = var.kubeconfig_path
  kubeconfig_context          = var.kubeconfig_context
}
