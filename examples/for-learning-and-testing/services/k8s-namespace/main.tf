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

provider "kubernetes" {
  # Pin to this specific version to work around a bug introduced in 1.11.0:
  # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
  # (Only for EKS)
  kubernetes = "= 1.10.0"

  load_config_file = var.kubeconfig_auth_type == "context"
  config_path      = var.kubeconfig_auth_type == "context" ? var.kubeconfig_path : null
  config_context   = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

  host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
  cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
  token                  = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null
}

module "namespace" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-namespace?ref=v1.0.8"
  source = "../../../../modules/services/k8s-namespace"

  name = var.name
}
