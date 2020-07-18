# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/elasticsearch?ref=v1.2.3"
  source = "../../../../modules/data-stores/elasticsearch"

  # Cluster Configurations
  domain_name           = var.domain_name
  elasticsearch_version = var.elasticsearch_version
  instance_type         = var.instance_type
  instance_count        = var.instance_count
  volume_type           = var.volume_type
  volume_size           = var.volume_size

  # Network Configurations

  # To keep this example simple, we run it in the default VPC, put everything in the same subnets, and allow access from
  # any source. In production, you'll want to use a custom VPC, private subnets, and explicitly close off access to only
  # those applications that need it.
  vpc_id                                 = data.aws_vpc.default.id
  subnet_ids                             = data.aws_subnet_ids.default.ids
  allow_connections_from_cidr_blocks     = ["0.0.0.0/0"]
  allow_connections_from_security_groups = []
  zone_awareness_enabled                 = var.zone_awareness_enabled

  # Since this is just an example, we don't deploy any CloudWatch resources in order to make it faster to deploy, however in
  # production you'll probably want to enable this feature.
  enable_cloudwatch_alarms = false
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD AN EC2 INSTANCE TO SERVE AS A BASTION HOST
# This instance will be used to run curl commands against the Elasticsearch cluster.
# ---------------------------------------------------------------------------------------------------------------------
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

resource "aws_instance" "server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  # Create the instance in the security group of the Elasticsearch cluster.
  # Alternatively, create it in a different security group which is included in var.allow_connections_from_security_groups
  vpc_security_group_ids      = [module.elasticsearch.cluster_security_group_id]
  subnet_id                   = tolist(data.aws_subnet_ids.default.ids)[0]
  key_name                    = var.keypair_name
  associate_public_ip_address = true
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
