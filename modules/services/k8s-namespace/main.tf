# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A NEW NAMESPACE AND OPTIONALLY SETUP WITH FARGATE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
      version = ">= 2.6, < 4.0"
    }

    # The underlying modules are only compatible with kubernetes provider 2.x
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SETUP NAMESPACE WITH DEFAULT ROLES AND ADD FARGATE PROFILE IF REQUESTED
# ---------------------------------------------------------------------------------------------------------------------

module "namespace" {
  source = "git::git@github.com:gruntwork-io/terraform-kubernetes-namespace.git//modules/namespace?ref=v0.5.0"

  name        = var.name
  labels      = var.labels
  annotations = var.annotations
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

resource "kubernetes_role_binding" "full_access_bindings" {
  count = length(var.full_access_rbac_entities) > 0 ? 1 : 0

  metadata {
    name      = "${module.namespace.name}-full-access-rbac-entities"
    namespace = module.namespace.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = module.namespace.rbac_access_all_role
  }

  dynamic "subject" {
    for_each = var.full_access_rbac_entities
    content {
      api_group = subject.value.kind != "ServiceAccount" ? "rbac.authorization.k8s.io" : null
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = subject.value.kind == "ServiceAccount" ? subject.value.namespace : null
    }
  }
}

resource "kubernetes_role_binding" "read_only_access_bindings" {
  count = length(var.read_only_access_rbac_entities) > 0 ? 1 : 0

  metadata {
    name      = "${module.namespace.name}-readonly-access-rbac-entities"
    namespace = module.namespace.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = module.namespace.rbac_access_read_only_role
  }

  dynamic "subject" {
    for_each = var.read_only_access_rbac_entities
    content {
      api_group = subject.value.kind != "ServiceAccount" ? "rbac.authorization.k8s.io" : null
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = subject.value.kind == "ServiceAccount" ? subject.value.namespace : null
    }
  }
}
