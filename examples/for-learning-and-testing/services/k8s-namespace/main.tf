# ----------------------------------------------------------------------------------------------------------------------
# PROVISION A NAMESPACE WITH DEFAULT RBAC ROLES
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 1.10.0"
    }
  }
}


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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/k8s-namespace?ref=v1.0.8"
  source = "../../../../modules/services/k8s-namespace"

  name = var.name
}