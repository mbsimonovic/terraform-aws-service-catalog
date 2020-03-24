# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN OPENVPN SERVER WITH CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "openvpn_server" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/openvpn-server?ref=v1.0.8"
  source = "../../../../modules/mgmt/openvpn-server"

  name = var.name
  ami  = var.ami

  # For this simple example, use a regular key pair instead of ssh-grunt
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets.
  vpc_id    = data.aws_vpc.default.id
  subnet_id = local.openvpn_subnet

  # Configure a host name for the openvpn server
  create_dns_record = true
  hosted_zone_id    = data.aws_route53_zone.zone.id
  domain_name       = "${var.name}.${var.domain_name}"

  backup_bucket_name = var.backup_bucket_name
  kms_key_arn        = var.kms_key_arn

  ca_cert_fields = {
    ca_country  = "US"
    ca_state    = "AZ"
    ca_locality = "Phoenix"
    ca_org      = "Gruntwork"
    ca_org_unit = "OpenVPN"
    ca_email    = "support@gruntwork.io"
  }

  # To keep this example simple, we allow incoming SSH connections from anywhere. In production, you should limit
  # access to a specific set of source CIDR ranges, like the addresses of your offices.
  allow_ssh_from_cidr_list = ["0.0.0.0/0"]
}
