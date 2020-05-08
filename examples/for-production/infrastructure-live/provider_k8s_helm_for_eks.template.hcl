data "aws_eks_cluster" "cluster" {
  name = "${eks_cluster_name}"
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name = "${eks_cluster_name}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.kubernetes_token.token
  }
}
