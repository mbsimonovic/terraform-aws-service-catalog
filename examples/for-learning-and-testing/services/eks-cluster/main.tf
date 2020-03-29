# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN EKS CLUSTER WITH SELF MANAGED WORKERS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/eks-cluster?ref=v1.0.8"
  source = "../../../../modules/services/eks-cluster"

  cluster_name                               = var.cluster_name
  cluster_instance_ami                       = var.cluster_instance_ami_id
  cluster_instance_type                      = "t3.small"
  schedule_control_plane_services_on_fargate = false

  # For this simple example, use a regular key pair instead of ssh-grunt
  cluster_instance_keypair_name = var.keypair_name
  enable_ssh_grunt              = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets. In production,
  # you'll want to use a custom VPC, with both the workers and control plane in a private subnet.
  vpc_id                       = data.aws_vpc.default.id
  control_plane_vpc_subnet_ids = data.aws_subnet_ids.default.ids

  # Due to localization limitations for EKS, it is recommended to have separate ASGs per availability zones. Here we
  # deploy one ASG in one subnet.
  autoscaling_group_configurations = {
    asg = {
      min_size   = 1
      max_size   = 2
      subnet_ids = [local.sorted_subnets[0]]
      tags       = []
    }
  }

  # To keep this example simple, we make the Control Plane public and allow incoming API calls and SSH connections from
  # anywhere. In production, you'll want to make the Control Plane private and limit access to trusted servers only
  # (e.g., solely a bastion host or VPN server).
  endpoint_public_access                    = true
  allow_inbound_api_access_from_cidr_blocks = ["0.0.0.0/0"]
  allow_inbound_ssh_from_cidr_blocks        = ["0.0.0.0/0"]
}
