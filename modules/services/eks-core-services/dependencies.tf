# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MODULE DEPENDENCIES
# These are data sources and computations that must be computed before the module resources can be created.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  count = var.use_exec_plugin_for_auth ? 0 : 1
  name  = var.eks_cluster_name
}

# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE THE SUBNETS TO USE
# Since EKS has restrictions by availability zones, we need to support filtering out the provided subnets that do not
# support EKS. Which subnets are allowed is based on the disallowed availability zones input.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_subnet" "provided_for_fargate_workers" {
  for_each = { for id in var.worker_vpc_subnet_ids : id => id }
  id       = each.key
}

locals {
  usable_fargate_subnet_ids = [
    for id, subnet in data.aws_subnet.provided_for_fargate_workers :
    id if contains(var.fargate_worker_disallowed_availability_zones, subnet.availability_zone) == false
  ]
}
