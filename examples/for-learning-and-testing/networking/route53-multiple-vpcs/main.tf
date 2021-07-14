# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 PRIVATE HOSTED ZONE WITH MULTIPLE VPCS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"
}


provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------------------------------------------------------------------------
# CREATE ROUTE53 PRIVATE ZONE
# ----------------------------------------------------------------------------------------------------------------------

module "route53" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/route53?ref=v1.2.3"
  source = "../../../../modules/networking/route53"

  private_zones = {
    "${var.domain_name}" = {
      comment = "Private zone with 2 VPCs."
      vpcs = [
        {
          id     = module.mgmt_vpc.vpc_id
          region = null
        },
        {
          id     = module.app_vpc.vpc_id
          region = null
        },
      ]
      tags          = {}
      force_destroy = true
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# CREATE TWO VPCS
# ----------------------------------------------------------------------------------------------------------------------

module "mgmt_vpc" {
  source = "../../../../modules/networking/vpc-mgmt"

  vpc_name         = "${var.vpc_name}-mgmt"
  aws_region       = var.aws_region
  cidr_block       = "10.0.0.0/16"
  num_nat_gateways = 1
  create_flow_logs = false
}

module "app_vpc" {
  source = "../../../../modules/networking/vpc"

  vpc_name         = "${var.vpc_name}-app"
  aws_region       = var.aws_region
  cidr_block       = "10.1.0.0/16"
  num_nat_gateways = 1
  create_flow_logs = false
}

# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN INSTANCE INTO EACH VPC FOR TESTING PURPOSES
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "example" {
  for_each = toset(["mgmt", "app"])
  vpc_id = (
    each.key == "mgmt"
    ? module.mgmt_vpc.vpc_id
    : module.app_vpc.vpc_id
  )

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # To simplify testing and for example purposes, we allow access to the instance from anywhere.
    # In production, you'll want to limit access to trusted systems only
    # (e.g., solely a bastion host or VPN server).
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  for_each      = toset(["mgmt", "app"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = module.instance_types.recommended_instance_type
  subnet_id = (
    each.key == "mgmt"
    ? element(module.mgmt_vpc.public_subnet_ids, 0)
    : element(module.app_vpc.public_subnet_ids, 0)
  )
  vpc_security_group_ids      = [aws_security_group.example[each.key].id]
  associate_public_ip_address = true
  key_name                    = var.example_instance_keypair_name
}
