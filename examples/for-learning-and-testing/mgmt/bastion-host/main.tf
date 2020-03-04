# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A BASTION HOST WITH CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "bastion" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/bastion-host?ref=v1.0.8"
  source = "../../../../modules/mgmt/bastion-host"

  name          = var.name
  instance_type = "t3.micro"
  ami           = var.ami_id

  # For this simple example, use a regular key pair instead of ssh-grunt
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets.
  vpc_id    = data.aws_vpc.default.id
  subnet_id = locals.bastion_subnet

  # Configure a host name for the bastion
  create_dns_record = true
  hosted_zone_id    = var.hosted_zone_id
  domain_name       = var.domain_name

  # To keep this example simple, we allow incoming SSH connections from anywhere. In production, you should limit
  # access to a specific set of source CIDR ranges, like the addresses of your offices.
  allow_ssh_from_cidr_list = ["0.0.0.0/0"]
}
