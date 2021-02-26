data "aws_eks_cluster" "cluster_for_provider" {
  name = "${eks_cluster_name}"
}

data "aws_eks_cluster_auth" "kubernetes_token_for_provider" {
  name = "${eks_cluster_name}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = data.aws_eks_cluster.cluster_for_provider.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_for_provider.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.kubernetes_token_for_provider.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster_for_provider.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_for_provider.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.kubernetes_token_for_provider.token
  }
}
