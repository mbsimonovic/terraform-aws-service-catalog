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
  schedule_control_plane_services_on_fargate = true

  # For this simple example, use a regular key pair instead of ssh-grunt
  cluster_instance_keypair_name = var.keypair_name
  enable_ssh_grunt              = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets. In production,
  # you'll want to use a custom VPC, with both the workers and control plane in a private subnet.
  vpc_id                       = data.aws_vpc.default.id
  control_plane_vpc_subnet_ids = local.sorted_subnets
  worker_vpc_subnet_ids        = [aws_subnet.private.id]

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

# ----------------------------------------------------------------------------------------------------------------------
# CREATE NAT GATEWAY AND PRIVATE SUBNET FOR DEFAULT VPC
# You can only run Fargate on private subnets. However, private subnets can not make outbound calls unless there is a
# NAT gateway, so we need to create that too.
# ----------------------------------------------------------------------------------------------------------------------

# A NAT Gateway must be associated with an Elastic IP Address
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = local.sorted_subnets[0]

  tags = {
    Name = "default-vpc-nat-for-${var.cluster_name}"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.all.names[0]
  cidr_block        = "172.31.200.0/24"
  tags = merge(
    {
      Name = "default-vpc-private"
    },
    module.vpc_tags.vpc_private_app_subnet_eks_tags
  )
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  tags = {
    Name = "default-vpc-private"
  }
}

resource "aws_route" "nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id

  # Workaround for https://github.com/terraform-providers/terraform-provider-aws/issues/338
  timeouts {
    create = "5m"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

data "aws_availability_zones" "all" {
  state = "available"
}

module "vpc_tags" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-vpc-tags?ref=v0.19.1"

  eks_cluster_names = [var.cluster_name]
}
