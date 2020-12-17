# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A NEW NAMESPACE AND OPTIONALLY SETUP WITH FARGATE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that has backwards incompatible changes that are known to NOT
  # work with the terraform-aws-eks repo. We are working on a fix, but until that's ready, we need to avoid 0.13.x.
  required_version = "~> 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }

    # Pin to this specific version to work around a bug introduced in 1.11.0:
    # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
    # (Only for EKS)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 1.10.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP NAMESPACE WITH DEFAULT ROLES AND ADD FARGATE PROFILE IF REQUESTED
# ---------------------------------------------------------------------------------------------------------------------

module "namespace" {
  source = "git::git@github.com:gruntwork-io/terraform-kubernetes-namespace.git//modules/namespace?ref=v0.1.0"

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

  # Fargate Profiles can take a long time to delete if there are Pods, since the nodes need to deprovision.
  timeouts {
    delete = "1h"
  }
}
