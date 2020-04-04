# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY SERVICE ON KUBERNETES USING THE k8s-service HELM CHART
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
  load_config_file = var.kubeconfig_auth_type == "context"
  config_path      = var.kubeconfig_auth_type == "context" ? var.kubeconfig_path : null
  config_context   = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

  host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
  cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
  token                  = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null
}

module "application" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-service?ref=v1.0.8"
  source = "../../../../modules/services/k8s-service"

  application_name = var.application_name
  container_image = {
    repository  = var.image
    tag         = var.image_version
    pull_policy = "IfNotPresent"
  }
  container_port = var.container_port
  namespace      = var.namespace
}
