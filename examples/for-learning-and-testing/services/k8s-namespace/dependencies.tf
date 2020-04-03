# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MODULE DEPENDENCIES
# These are data sources and computations that must be computed before the module resources can be created.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "aws_eks_cluster" "cluster" {
  count = var.kubeconfig_auth_type == "eks" ? 1 : 0
  name  = var.kubeconfig_eks_cluster_name
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  count = var.kubeconfig_auth_type == "eks" ? 1 : 0
  name  = var.kubeconfig_eks_cluster_name
}
