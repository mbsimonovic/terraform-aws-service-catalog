# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A NEW NAMESPACE AND OPTIONALLY SETUP WITH FARGATE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"

    # Pin to this specific version to work around a bug introduced in 1.11.0:
    # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
    kubernetes = "= 1.10.0"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP NAMESPACE WITH DEFAULT ROLES AND ADD FARGATE PROFILE IF REQUESTED
# ---------------------------------------------------------------------------------------------------------------------

module "namespace" {
  source = "git::git@github.com:gruntwork-io/terraform-kubernetes-helm.git//modules/k8s-namespace?ref=v0.6.1"

  name = var.name
}

resource "aws_eks_fargate_profile" "namespace" {
  count = var.schedule_pods_on_fargate ? 1 : 0

  cluster_name           = var.eks_cluster_name
  fargate_profile_name   = "all-${var.name}-namespace"
  pod_execution_role_arn = var.pod_execution_iam_role_arn
  subnet_ids             = var.worker_vpc_subnet_ids

  selector {
    namespace = var.name
  }
}
