# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 HOSTED ZONE FOR INTERNAL DNS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
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
  dynamic "vpc" {
    for_each = each.value.vpcs
    content {
      vpc_id     = vpc.value.id
      vpc_region = vpc.value.region
    }
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

  name = lookup(each.value, "hosted_zone_domain_name", null) != null ? each.value.hosted_zone_domain_name : each.key

  tags = lookup(each.value, "base_domain_name_tags", null) != null ? each.value.base_domain_name_tags : {}

  private_zone = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE NS RECORDS FOR NESTED ROUTE 53 ZONES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "ns" {
  for_each = local.delegated_domains
  zone_id  = each.value.parent_hosted_zone_id

  type            = "NS"
  name            = each.key
  allow_overwrite = true
  records         = aws_route53_zone.public_zones[each.key].name_servers

  # Common TTL for NS records, as documented by AWS:
  # https://aws.amazon.com/premiumsupport/knowledge-center/create-subdomain-route-53/
  ttl = 172800
}

data "aws_route53_zone" "parent_hosted_zone" {
  for_each = local.delegated_domains
  zone_id  = each.value.parent_hosted_zone_id
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
  source               = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/acm-tls-certificate?ref=v0.27.0"
  acm_tls_certificates = local.acm_tls_certificates

  # Workaround Terraform limitation where there is no module depends_on.
  # See https://github.com/hashicorp/terraform/issues/1178 for more details.
  # This effectively draws an explicit dependency between the public
  # and private zones managed here and the ACM certificates that will be optionally
  # provisioned for them
  dependencies = flatten(concat([
    values(aws_route53_zone.public_zones).*.name_servers,
    values(aws_service_discovery_public_dns_namespace.namespaces).*.id,
    values(aws_route53_record.ns).*.id,
  ]))
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCAL VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Build a map of objects representing public zones that are delegated (subdomains of existing hosted zones). This map
  # will be used to determine which domains need to create NS records in the parent hosted zone.
  delegated_domains = {
    for domain, zone in var.public_zones :
    domain => zone if !zone.created_outside_terraform && lookup(zone, "parent_hosted_zone_id", null) != null
  }

  # Build a map of objects representing ACM certificates to request, which will be merged together with
  # service_discovery_namespace_acml_tls_certificates and provided as input to the acm-tls-certificates module
  route53_acm_tls_certificates = {
    for domain, zone in var.public_zones :
    # See var.public_zones in variables.tf for example scenarios for requesting certificates that cover either the
    # apex domain (example.com) only, or a wildcard cert that covers first-level subdomains (such as mail.example.com,
    # test.example.com, etc) or both (example.com AND *.example.com).
    domain => {
      tags                       = zone.tags
      subject_alternative_names  = zone.subject_alternative_names
      create_verification_record = lookup(zone, "create_verification_record", true)
      verify_certificate         = lookup(zone, "verify_certificate", true)
      # If the created_outside_terraform attribute is set to true, the zone ID will be looked up dynamically
      hosted_zone_id = zone.created_outside_terraform ? (zone.hosted_zone_domain_name != "" ? data.aws_route53_zone.selected[zone.hosted_zone_domain_name].zone_id : data.aws_route53_zone.selected[domain].zone_id) : ""
    }
    if lookup(zone, "provision_certificates", true)
  }
  # Build a map of objects representing ACM certificates to request, which will be merged together with
  # route53_acm_tls_certificates and provided as input to the acm-tls-certificates module
  service_discovery_namespace_acm_tls_certificates = {
    for domain, config in var.service_discovery_public_namespaces :
    # See var.service_discovery_public_namespaces in variables.tf for example scenarios for requesting certificates that
    # cover both the apex domain (example.com) only, or a wildcard cert that covers first-level subdomains
    # (such as mail.example.com, test.example.com, etc) or both (example.com AND *.example.com).
    domain => {
      tags                       = {}
      subject_alternative_names  = config.subject_alternative_names
      create_verification_record = lookup(config, "create_verification_record", true)
      verify_certificate         = lookup(config, "verify_certificate", true)
      hosted_zone_id             = config.created_outside_terraform ? data.aws_route53_zone.selected[config.hosted_zone_domain_name].zone_id : ""
    }
    if lookup(config, "provision_certificates", true)
  }
  acm_tls_certificates = merge(local.route53_acm_tls_certificates, local.service_discovery_namespace_acm_tls_certificates)

  # The zones that should be pulled in via data sources as opposed to created and managed by this module.
  existing_zones_to_lookup = {
    for domain, zone in merge(var.public_zones, var.service_discovery_public_namespaces) :
    (zone.hosted_zone_domain_name != "" ? zone.hosted_zone_domain_name : domain) => zone if zone.created_outside_terraform
  }
}
