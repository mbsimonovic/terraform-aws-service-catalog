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
  schedule_control_plane_services_on_fargate = true
  cluster_instance_ami                       = null
  cluster_instance_ami_filters = {
    owners = ["self"]
    filters = [
      {
        name   = "tag:service"
        values = ["eks-workers"]
      },
      {
        name   = "tag:version"
        values = [var.cluster_instance_ami_version_tag]
      },
    ]
  }

  # For this simple example, use a regular key pair instead of ssh-grunt
  cluster_instance_keypair_name = var.keypair_name

  # When these groups are blank, ssh-grunt is disabled
  ssh_grunt_iam_group      = ""
  ssh_grunt_iam_group_sudo = ""

  vpc_id                       = module.vpc.vpc_id
  control_plane_vpc_subnet_ids = module.vpc.private_app_subnet_ids
  worker_vpc_subnet_ids        = module.vpc.private_app_subnet_ids

  # Due to localization limitations for EKS, it is recommended to have separate ASGs per availability zones. Here we
  # deploy one ASG in one public subnet. We use public subnets so we can SSH into the node for testing.
  autoscaling_group_configurations = {
    asg = {
      min_size          = 1
      max_size          = 2
      subnet_ids        = [module.vpc.public_subnet_ids[0]]
      asg_instance_type = "t3.small"
      tags              = []
    }
  }

  # To keep this example simple, we make the Control Plane public and allow incoming API calls and SSH connections from
  # anywhere. In production, you'll want to make the Control Plane private and limit access to trusted servers only
  # (e.g., solely a bastion host or VPN server).
  endpoint_public_access                       = true
  cluster_instance_associate_public_ip_address = true
  allow_inbound_api_access_from_cidr_blocks    = ["0.0.0.0/0"]
  allow_inbound_ssh_from_cidr_blocks           = ["0.0.0.0/0"]

  # Configuration variables for the aws-auth-merger
  enable_aws_auth_merger = var.enable_aws_auth_merger
  aws_auth_merger_image  = var.aws_auth_merger_image
}

# ----------------------------------------------------------------------------------------------------------------------
# CREATE A VPC
# You can only run Fargate on private subnets, and the default VPC does not come with private subnets with NAT gateways
# for outbound calls, so we create a new VPC here to accommodate.
# ----------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "../../../../modules/networking/vpc"

  aws_region           = var.aws_region
  cidr_block           = "10.0.0.0/16"
  num_nat_gateways     = 1
  vpc_name             = var.cluster_name
  create_flow_logs     = false
  tag_for_use_with_eks = true
  eks_cluster_names    = [var.cluster_name]
}


# ----------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH DASHBOARD WITH METRICS FOR THE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "dashboard" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.20.0"

  dashboards = {
    (var.cluster_name) = [
      module.eks_cluster.metric_widget_worker_cpu_usage,
      module.eks_cluster.metric_widget_worker_memory_usage,
      module.eks_cluster.metric_widget_worker_disk_usage,
    ]
  }
}
