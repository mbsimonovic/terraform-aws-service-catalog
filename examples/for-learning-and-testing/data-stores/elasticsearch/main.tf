# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.35"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

}

locals {
  ssh_port = 22
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/elasticsearch?ref=v1.2.3"
  source = "../../../../modules/data-stores/elasticsearch"

  # Cluster Configurations
  domain_name            = var.domain_name
  elasticsearch_version  = "7.7"
  instance_type          = "t3.small.elasticsearch"
  instance_count         = 1
  volume_type            = "gp2"
  volume_size            = 10
  zone_awareness_enabled = false

  # Network Configurations

  # To keep this example simple, we run it in the default VPC, put everything in the same subnets, and allow access from
  # any source.
  # NOTE: However, even with Elasticsearch deployed in a public subnet in the default VPC, it is still only accessible from within the VPC.
  # https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-vpc.html#es-vpc-security
  # In production, you can use a custom VPC, private subnets, and explicitly close off access to only
  # those applications that need it.
  vpc_id                                 = data.aws_vpc.default.id
  subnet_ids                             = data.aws_subnet_ids.default.ids
  allow_connections_from_cidr_blocks     = ["0.0.0.0/0"]
  allow_connections_from_security_groups = [aws_security_group.elasticsearch_bastion.id]

  # Since this is just an example, we don't deploy any CloudWatch resources in order to make it faster to deploy, however in
  # production you'll probably want to enable this feature.
  enable_cloudwatch_alarms = false

  # Encryption config.
  # Since this is just an example, we use the default service KMS key when encryption at rest is
  # enabled. However, in production, you will want to configure a dedicated encryption KMS key.
  enable_encryption_at_rest = var.enable_encryption_at_rest
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD AN EC2 INSTANCE TO SERVE AS A BASTION HOST
# This instance is used to run curl commands against the Elasticsearch cluster.
# For your production use cases, you may wish to use a VPN tunnel instead of a bastion host.
# ---------------------------------------------------------------------------------------------------------------------

# First define the AMI to use for the instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create a new security group for this instance.
# Include this security group in var.allow_connections_from_security_groups
resource "aws_security_group" "elasticsearch_bastion" {
  name   = "elasticsearch-bastion-${var.keypair_name}"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.elasticsearch_bastion.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_inbound_ssh" {
  type              = "ingress"
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_bastion.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Use this utility to find an instance type for the bastion host
# that exists in all availability zones for the AWS region in use.
module "lookup_instance_type" {
  source         = "git::git@github.com:gruntwork-io/terraform-aws-utilities.git//modules/instance-type?ref=v0.6.0"
  instance_types = ["t2.micro", "t3.micro"]
}

# Finally define the bastion host!
resource "aws_instance" "server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = module.lookup_instance_type.recommended_instance_type

  vpc_security_group_ids      = [aws_security_group.elasticsearch_bastion.id]
  subnet_id                   = tolist(data.aws_subnet_ids.default.ids)[0]
  key_name                    = var.keypair_name
  associate_public_ip_address = true
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA: Use the default VPC for this example.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}