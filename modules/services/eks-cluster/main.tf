# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN EKS CLUSTER TO RUN DOCKER CONTAINERS
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
# CONFIGURE KUBERNETES CONNECTION TO SETUP IAM ROLE MAPPING
# Note that we can't configure our Kubernetes connection until EKS is up and running, so we try to depend on the
# resource being created.
# ---------------------------------------------------------------------------------------------------------------------

# The provider needs to depend on the cluster being setup.
provider "kubernetes" {
  load_config_file       = false
  host                   = data.template_file.kubernetes_cluster_endpoint.rendered
  cluster_ca_certificate = base64decode(data.template_file.kubernetes_cluster_ca.rendered)
  token                  = data.aws_eks_cluster_auth.kubernetes_token.token
}

# Workaround for Terraform limitation where you cannot directly set a depends on directive or interpolate from resources
# in the provider config.
# Specifically, Terraform requires all information for the Terraform provider config to be available at plan time,
# meaning there can be no computed resources. We work around this limitation by creating a template_file data source
# that does the computation.
# See https://github.com/hashicorp/terraform/issues/2430 for more details
data "template_file" "kubernetes_cluster_endpoint" {
  template = module.eks_cluster.eks_cluster_endpoint
}

data "template_file" "kubernetes_cluster_ca" {
  template = module.eks_cluster.eks_cluster_certificate_authority
}

data "aws_eks_cluster_auth" "kubernetes_token" {
  name = module.eks_cluster.eks_cluster_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE EKS CLUSTER WITH A WORKER POOL
# ---------------------------------------------------------------------------------------------------------------------

module "eks_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-control-plane?ref=v0.15.4"

  cluster_name = var.cluster_name

  vpc_id                       = var.vpc_id
  vpc_master_subnet_ids        = var.control_plane_vpc_subnet_ids
  endpoint_public_access_cidrs = var.allow_inbound_api_access_from_cidrs

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  kubernetes_version        = var.kubernetes_version
  endpoint_public_access    = var.endpoint_public_access
}

module "eks_workers" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-cluster-workers?ref=v0.15.4"

  cluster_name = var.cluster_name

  vpc_id                = var.vpc_id
  vpc_worker_subnet_ids = var.worker_vpc_subnet_ids

  eks_master_security_group_id = module.eks_cluster.eks_master_security_group_id

  cluster_min_size = var.cluster_min_size
  cluster_max_size = var.cluster_max_size

  cluster_instance_ami          = var.cluster_instance_ami
  cluster_instance_type         = var.cluster_instance_type
  cluster_instance_keypair_name = var.cluster_instance_keypair_name
  cluster_instance_user_data    = data.template_file.user_data.rendered

  tenancy = var.tenancy
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_security_groups" {
  for_each = length(var.allow_inbound_ssh_from_security_groups) > 0 ? toset(var.allow_inbound_ssh_from_security_groups) : {}

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.eks_workers.eks_worker_security_group_id
  source_security_group_id = each.key
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON EACH INSTANCE IN THE EKS CLUSTER
# This script will configure each instance so it registers in the right EKS cluster.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    aws_region                = var.aws_region
    eks_cluster_name          = var.cluster_name
    eks_endpoint              = module.eks_cluster.eks_cluster_endpoint
    eks_certificate_authority = module.eks_cluster.eks_cluster_certificate_authority
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE EKS IAM ROLE MAPPINGS
# We will map AWS IAM roles to RBAC roles in Kubernetes. By doing so, we:
# - allow access to the EKS cluster when assuming mapped IAM role
# - manage authorization for those roles using RBAC role resources in Kubernetes
# Here, we bind the following permissions:
# - The Worker IAM roles should have node level permissions
# - The full-access roles should have admin level permissions
# ---------------------------------------------------------------------------------------------------------------------

module "eks_k8s_role_mapping" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-k8s-role-mapping?ref=v0.15.4"

  eks_worker_iam_role_arns = [module.eks_workers.eks_worker_iam_role_arn]

  iam_role_to_rbac_group_mappings = var.iam_role_to_rbac_group_mapping
  iam_user_to_rbac_group_mappings = var.iam_user_to_rbac_group_mapping

  config_map_labels = {
    eks-cluster = module.eks_cluster.eks_cluster_name
  }
}
