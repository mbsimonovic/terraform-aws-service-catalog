# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 HOSTED ZONE FOR INTERNAL DNS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE PRIVATE HOSTED ZONE(S)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_zone" "private_zones" {
  for_each = var.private_zones

  # Normalize zone name - whether the user added a trailing dot or not, ensure the trailing dot is present
  # This helps prevent some state change errors where the AWS provider may return a zone name with a trailing dot,
  # which causes Terraform to see the input map that is provided to for_each loops has been changed at runtime,
  # leading to very obscure errors
  name    = "${trimsuffix(each.key, ".")}."
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
  # We need only create new zones when the created_outside_terraform attribute is false. If created_outside_terraform is set to true, it means a that a
  # public hosted zone with this name already exists, as is often the case if the target AWS account registered a domain
  # via route 53 which automatically creates a new public hosted zone for the domain. In these cases, we'll dynamically look up
  # the existing zone's ID and pass it through to acm certificates modules so that it knows the correct hosted zone to write DNS
  # validation records to which are required by ACM to complete certificate validation and issuance
  for_each = {
    for domain, zone in var.public_zones :
    domain => zone if !zone.created_outside_terraform
  }
  # Normalize zone name - whether the user added a
  # trailing dot or not, ensure the trailing dot is present
  # This helps prevent some state change errors where the AWS
  # provider may return a zone name with a trailing dot,
  # which causes Terraform to see the input map that is
  # provided to for_each loops has been changed at runtime
  # which leads to very obscure errors
  name    = "${trimsuffix(each.key, ".")}."
  comment = each.value.comment

  tags = each.value.tags

  force_destroy = each.value.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP THE ZONE IDS FOR ANY EXISTING PUBLIC ZONES
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "selected" {
  for_each = local.existing_zones_to_lookup

  name = each.key

  tags = each.value.base_domain_name_tags != null ? each.value.base_domain_name_tags : {}

  private_zone = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AWS CLOUD MAP NAMESPACES
# ---------------------------------------------------------------------------------------------------------------------

# Public
resource "aws_service_discovery_public_dns_namespace" "namespaces" {
  for_each    = var.service_discovery_public_namespaces
  name        = each.key
  description = each.value.description
}

# Private
resource "aws_service_discovery_private_dns_namespace" "namespaces" {
  for_each    = var.service_discovery_private_namespaces
  name        = each.key
  vpc         = each.value.vpc_id
  description = each.value.description
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AMAZON CERTIFICATE MANAGER (ACM) TLS CERTIFICATES
# ---------------------------------------------------------------------------------------------------------------------

module "acm-tls-certificates" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/acm-tls-certificate?ref=v0.23.0"

  source               = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/acm-tls-certificate?ref=v0.23.0"
  acm_tls_certificates = local.acm_tls_certificates

  # Workaround Terraform limitation where there is no module depends_on.
  # See https://github.com/hashicorp/terraform/issues/1178 for more details.
  # This effectively draws an explicit dependency between the public
  # and private zones managed here and the ACM certificates that will be optionally
  # provisioned for them
  dependencies = flatten(concat([
    values(aws_route53_zone.public_zones).*.name_servers,
    values(aws_service_discovery_public_dns_namespace.namespaces).*.id,
  ]))
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCAL VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

locals {

  # For public zones and namespaces with their `provision_wildcard_certificate` attribute set to true, build a map that
  # will be provided as input to the acm-tls-certificates module
  route53_acm_tls_certificates = {
    for domain, zone in var.public_zones :
    # We create the local object that is fed into our terraform-aws-load-balancer module by using the apex domain name
    # as the key name and supplying the wildcard prefix of "*.${domain}" as a subject alternative name (SAN) so that
    # the final result is a single ACM certificate that covers the apex domain of example.com AND *.example.com

    # A wildcard certificate for example.com, requested with a domain of *.example.com, will protect all one-level
    # subdomains of example.com, such as mail.example.com, admin.example.com. Meanwhile, the apex domain of example.com
    # is explicitly supplied for the domain entry of the underlying terraform aws_acm_certificate resource.
    # This means you can use the same cert to protect example.com, mail.example.com, static.example.com, etc.
    domain => {
      tags                       = zone.tags
      subject_alternative_names  = ["*.${domain}"]
      create_verification_record = true
      verify_certificate         = true
      # If the created_outside_terraform attribute is set to true, the zone ID will be looked up dynamically
      hosted_zone_id = zone.created_outside_terraform ? data.aws_route53_zone.selected[domain].zone_id : ""
      # Only issue wildcard certificates for those zones where they were requested
    } if zone.provision_wildcard_certificate
  }
  service_discovery_namespace_acm_tls_certificates = {
    for domain, config in var.service_discovery_public_namespaces :
    # We create the local object that is fed into our terraform-aws-load-balancer module by using the apex domain name
    # as the key name and supplying the wildcard prefix of "*.${domain}" as a subject alternative name (SAN) so that
    # the final result is a single ACM certificate that covers the apex domain of example.com AND *.example.com

    # A wildcard certificate for example.com, requested with a domain of *.example.com, will protect all one-level
    # subdomains of example.com, such as mail.example.com, admin.example.com. Meanwhile, the apex domain of example.com
    # is explicitly supplied for the domain entry of the underlying terraform aws_acm_certificate resource.
    # This means you can use the same cert to protect example.com, mail.example.com, static.example.com, etc.
    domain => {
      tags                       = {}
      subject_alternative_names  = ["*.${domain}"]
      create_verification_record = true
      verify_certificate         = true
      hosted_zone_id             = ""
      # Only issue wildcard certificates for those zones where they were requested
    } if config.provision_wildcard_certificate
  }
  acm_tls_certificates = merge(local.route53_acm_tls_certificates, local.service_discovery_namespace_acm_tls_certificates)

  # The zones that should be pulled in via data sources as opposed to created and managed by this module.
  existing_zones_to_lookup = {
    for domain, zone in var.public_zones :
    domain => zone if zone.created_outside_terraform
  }
}
