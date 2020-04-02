# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN OPENVPN SERVER WITH CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "openvpn" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/openvpn-server?ref=v1.0.8"
  source = "../../../../modules/mgmt/openvpn-server"

  name          = var.name
  ami_id        = var.ami_id
  instance_type = var.instance_type

  # For this simple example, use a regular key pair instead of ssh-grunt
  # For details on ssh-grunt, see: https://github.com/gruntwork-io/module-security/blob/master/modules/ssh-grunt/README.adoc
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets.
  vpc_id    = data.aws_vpc.default.id
  subnet_id = local.openvpn_subnet

  # Configure a host name for the openvpn server
  create_route53_entry = true
  hosted_zone_id       = data.aws_route53_zone.zone.id
  domain_name          = var.domain_name

  # Back up the OpenVPN server PKI to an S3 bucket
  backup_bucket_name = var.backup_bucket_name

  # Encrypt the backed up PKI with an existing or new KMS Customer Master Key (CMK)
  kms_key_arn                = var.kms_key_arn
  cmk_administrator_iam_arns = var.cmk_administrator_iam_arns
  cmk_user_iam_arns          = var.cmk_user_iam_arns
  cmk_external_user_iam_arns = var.cmk_external_user_iam_arns

  vpn_route_cidr_blocks = [data.aws_vpc.default.cidr_block]

  ca_cert_fields = {
    ca_country  = "US"
    ca_state    = "AZ"
    ca_locality = "Phoenix"
    ca_org      = "Gruntwork"
    ca_org_unit = "OpenVPN"
    ca_email    = "support@gruntwork.io"
  }

  # To keep this example simple, we allow incoming connections from anywhere. In production, you should limit
  # access to a specific set of source CIDR ranges, like the addresses of your offices.
  allow_ssh_from_cidr_list = ["0.0.0.0/0"]
  allow_vpn_from_cidr_list = ["0.0.0.0/0"]

  # This will automatically delete the backups bucket when running terraform destroy
  # In production, you may want to keep the backups, so you would set this to false. 
  force_destroy = true
}