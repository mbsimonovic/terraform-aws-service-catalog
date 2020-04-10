# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 HOSTED ZONE FOR INTERNAL DNS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.

  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PRIVATE HOSTED ZONE(S) 
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_zone" "private_zones" {
  for_each = var.private_zones

  name    = each.key
  comment = each.value.comment

  # The presence of the VPC association here signifies that this zone will be private. 
  # Public zones do not require a VPC association 

  # See https://www.terraform.io/docs/providers/aws/r/route53_zone.html#private-zone
  # for more information 
  vpc {
    vpc_id = each.value.vpc_id
  }

  tags = each.value.tags

  force_destroy = each.value.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PUBLIC HOSTED ZONE(S)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_zone" "public_zones" {
  for_each = var.public_zones

  name    = each.key
  comment = each.value.comment

  tags = each.value.tags

  force_destroy = each.value.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PUBLIC HOSTED ZONE(S)
# ---------------------------------------------------------------------------------------------------------------------

module "acm-tls-certificates" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/route53?ref=v1.2.3"
  #source = "git::git@github.com:gruntwork-io/module-load-balancer.git//modules/acm-tls-certificate?ref=v0.19.0"

  # TODO: Replace me when the latest module-load-balancer ref is released 
  source = "../../../../module-load-balancer/modules/acm-tls-certificate/"

  # Pass in the nested map of certificate requests
  # built locally from var.public_zones 
  acm_tls_certificates = {
    for domain, zone in aws_route53_zone.public_zones :
    # These certificates that are going to be
    # automatically issued and verified for
    # public Route53 zones, so we prefix them
    # with *. to denote we are requesting
    # "wildcard" certificates

    # A wildcard certificate for example.com,
    # requested with a domain of *.example.com,
    # will protect all one-level subdomains of example.com,
    # such as mail.example.com, admin.example.com, etc
    "*.${zone.name}" => {
      tags                       = zone.tags
      subject_alternative_names  = []
      create_verification_record = true
      verify_certificate         = true
      bare_domain                = zone.name
      # Only issue wildcard certificates for those zones 
      # where they were requested 
    } if var.public_zones[domain].provision_wildcard_certificate
  }
}
