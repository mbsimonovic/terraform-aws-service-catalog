# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY SERVICE ON KUBERNETES USING THE K8S-SERVICE HELM CHART
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

provider "helm" {
  kubernetes {
    load_config_file = var.kubeconfig_auth_type == "context"
    config_path      = var.kubeconfig_auth_type == "context" ? var.kubeconfig_path : null
    config_context   = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

    host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
    cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
    token                  = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null
  }
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
  expose_type    = var.expose_type

  create_route53_entry = var.domain_name != null
  domain_name          = var.domain_name != null ? var.domain_name : ""

  # If you want to debug the Helm chart, you can set this parameter to output the chart values to a file
  values_file_path = "${path.module}/debug_values.yaml"

  # To make it easier to test, we allow force destroying the ALB access logs but in production, you will want to set
  # this to false so that the access logs are not accidentally destroyed permanently.
  force_destroy_ingress_access_logs  = true
  ingress_access_logs_s3_bucket_name = "gruntwork-service-catalog-test-${var.application_name}-alb-access-logs"
}
