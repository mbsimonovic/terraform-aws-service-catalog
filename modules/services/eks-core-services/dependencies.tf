# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MODULE DEPENDENCIES
# These are data sources and computations that must be computed before the module resources can be created.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name = var.eks_cluster_name
}
