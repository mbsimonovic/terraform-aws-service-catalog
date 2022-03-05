# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN EC2 INSTANCE WITH CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "path" {
  # t2.micro and t3.micro instances are not available in all regions. The instance-type module reconciles that.
  source         = "git::git@github.com:gruntwork-io/terraform-aws-utilities.git//modules/instance-type?ref=v0.7.0"
  instance_types = ["t2.micro", "t3.micro"]
}

module "ec2_instance" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/ec2-instance?ref=v1.0.8"
  source = "../../../../modules/services/ec2-instance"

  name          = var.name
  instance_type = module.path.recommended_instance_type
  ami           = null
  ami_filters = {
    owners = ["self"]
    filters = [
      {
        name   = "tag:service"
        values = ["ec2-instance"]
      },
      {
        name   = "tag:version"
        values = [var.ami_version_tag]
      },
    ]
  }
  # t2.micro instances don't support EBS optimization, so set it to false whenever a t2.micro is selected
  ebs_optimized = var.ebs_optimized

  # For this simple example, use a regular key pair instead of ssh-grunt
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets.
  vpc_id    = data.aws_vpc.default.id
  subnet_id = local.ec2_instance_subnet

  # Configure a host name for the EC2 instance
  create_dns_record     = var.create_dns_record
  base_domain_name_tags = var.base_domain_name_tags

  # We set the root volume size to be the default value in this example
  root_volume_size = var.root_volume_size

  # To keep this example simple, we create a single EBS volume
  ebs_volumes = {
    "demo-volume" = {
      type        = "gp2"
      size        = 5
      device_name = "/dev/xvdf"
      mount_point = "/mnt/demo"
      region      = var.aws_region
      owner       = "ubuntu"
    },
  }

  cloud_init_parts = local.cloud_init

  # To keep this example simple, we allow incoming SSH connections from anywhere. In production, you should limit
  # access to a specific set of source CIDR ranges, like the addresses of your offices.

  allow_ssh_from_cidr_blocks = ["0.0.0.0/0"]

  allow_ssh_from_security_group_ids  = []
  allow_port_from_cidr_blocks        = {}
  allow_port_from_security_group_ids = {}

  route53_zone_id            = ""
  dns_zone_is_private        = true
  route53_lookup_domain_name = ""
}

locals {
  cloud_init = {
    "touch-file" = {
      filename     = "touch-file"
      content_type = "text/x-shellscript"
      content      = local.user_data
    }
  }

  user_data = file("${path.module}/user-data.sh")
}
