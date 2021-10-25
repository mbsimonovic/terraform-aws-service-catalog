# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN EKS CLUSTER WITH SELF MANAGED WORKERS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-cluster?ref=v1.0.8"
  source = "../../../../modules/services/eks-cluster"

  cluster_name                               = var.cluster_name
  schedule_control_plane_services_on_fargate = true

  # If we are using a fargate only cluster, set the AMI ID to a random string that won't be used. The primary purpose of
  # this is to avoid the AMI filter based lookup that the module performs.
  cluster_instance_ami = var.fargate_only ? "do-not-use" : null
  cluster_instance_ami_filters = (
    var.fargate_only
    ? null
    : {
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
  )

  # For this simple example, use a regular key pair instead of ssh-grunt
  cluster_instance_keypair_name = var.keypair_name

  # When these groups are blank, ssh-grunt is disabled
  ssh_grunt_iam_group      = ""
  ssh_grunt_iam_group_sudo = ""

  vpc_id                           = module.vpc.vpc_id
  control_plane_vpc_subnet_ids     = module.vpc.private_app_subnet_ids
  num_control_plane_vpc_subnet_ids = module.vpc.num_availability_zones
  worker_vpc_subnet_ids            = module.vpc.private_app_subnet_ids
  num_worker_vpc_subnet_ids        = module.vpc.num_availability_zones

  # Due to localization limitations for EKS, it is recommended to have separate ASGs per availability zones. Here we
  # deploy one ASG in one public subnet. We use public subnets so we can SSH into the node for testing.
  autoscaling_group_configurations = (
    var.fargate_only
    ? {}
    : {
      asg = {
        min_size          = 1
        max_size          = 2
        subnet_ids        = [module.vpc.public_subnet_ids[0]]
        asg_instance_type = "t3.small"
        tags              = []
      }
    }
  )
  managed_node_group_configurations = (
    var.fargate_only
    ? {}
    : {
      node_group = {
        min_size       = 1
        max_size       = 2
        subnet_ids     = [module.vpc.public_subnet_ids[0]]
        instance_types = ["t3.small"]
      }
    }
  )

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.30.2"

  dashboards = {
    (var.cluster_name) = [
      module.eks_cluster.metric_widget_worker_cpu_usage,
      module.eks_cluster.metric_widget_worker_memory_usage,
      module.eks_cluster.metric_widget_worker_disk_usage,
    ]
  }
}
