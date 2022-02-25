# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 HOSTED ZONE FOR INTERNAL DNS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6, < 4.0"
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
# CREATE REQUESTED APEX RECORDS FOR PUBLIC DOMAINS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "apex" {
  count = length(local.public_apex_records)

  zone_id = local.hosted_zone_id_lookup[local.public_apex_records[count.index].name]

  name            = local.public_apex_records[count.index].name
  type            = local.public_apex_records[count.index].type
  ttl             = local.public_apex_records[count.index].ttl
  records         = local.public_apex_records[count.index].records
  allow_overwrite = true
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE REQUESTED SUBDOMAIN RECORDS FOR PUBLIC DOMAINS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "public" {
  for_each = local.public_subdomains

  zone_id = local.hosted_zone_id_lookup[each.value.root_domain]

  name            = each.key
  type            = each.value.config.type
  ttl             = each.value.config.ttl
  records         = each.value.config.records
  allow_overwrite = true
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/acm-tls-certificate?ref=v0.27.3"

  acm_tls_certificates   = local.acm_tls_certificates
  domain_hosted_zone_ids = local.hosted_zone_id_lookup

  # Terraform 0.13+ supports module depends_on now, but using depends_on on modules has the adverse side effect of
  # marking every data source in the module to only be available at apply time. This causes perpetual diff issues and
  # unnecessary resource tainting, so we avoid using module depends_on and instead rely on the dependencies pattern.
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

  # Build a map for looking up the hosted zone information. This is useful to avoid linking for_each clauses to dynamic
  # data, which has the unfortunate side effect of tainting the resources.
  hosted_zone_id_lookup = merge(
    # The map of domain to zone id. Look up the zone id by domain if the zone config doesn't have an explicit 
    # hosted_zone_domain_name set, for public zones.
    {
      for domain, zone in var.public_zones :
      domain => (
        zone.created_outside_terraform
        ? data.aws_route53_zone.selected[domain].zone_id
        : aws_route53_zone.public_zones[domain].zone_id
      )
      if lookup(zone, "hosted_zone_domain_name", "") == ""
    },
    # The map of domain to zone id. Look up the zone id by domain name if the zone config has an explicit 
    # hosted_zone_domain_name set, for public zones.
    {
      for domain, zone in var.public_zones :
      domain => (
        zone.created_outside_terraform
        ? data.aws_route53_zone.selected[zone.hosted_zone_domain_name].zone_id
        : aws_route53_zone.public_zones[zone.hosted_zone_domain_name].zone_id
      )
      if lookup(zone, "hosted_zone_domain_name", "") != ""
    },
    # The map of domain to zone id for cloud map namespaces. Look up the zone id by domain if the cloud map config 
    # doesn't have an explicit hosted zone domain name set.
    {
      for domain, config in var.service_discovery_public_namespaces :
      domain => (
        config.created_outside_terraform
        ? data.aws_route53_zone.selected[domain].zone_id
        : aws_service_discovery_public_dns_namespace.namespaces[domain].hosted_zone
      )
      if lookup(config, "hosted_zone_domain_name", "") == ""
    },
    # The map of domain to zone id for cloud map namespaces if the cloud map config has an explicit hosted zone
    # domain name set.
    {
      for domain, config in var.service_discovery_public_namespaces :
      domain => (
        config.created_outside_terraform
        ? data.aws_route53_zone.selected[config.hosted_zone_domain_name].zone_id
        : aws_service_discovery_public_dns_namespace.namespaces[config.hosted_zone_domain_name].hosted_zone
      )
      if lookup(config, "hosted_zone_domain_name", "") != ""
    },
    # The map of domain to zone id for private zones.
    {
      for domain, zone in var.private_zones :
      domain => aws_route53_zone.private_zones[domain].zone_id
    },
  )

  # Build a map of objects representing the subdomains to create.
  # First, we take the subdomains field on each domain and extract the information we need to create the
  # aws_route53_record resources. The output of this expression is a list of objects.
  public_subdomains_pairs = flatten(
    [
      for domain, zone in var.public_zones :
      [
        for subdomain, config in lookup(zone, "subdomains", {}) :
        {
          name        = "${subdomain}.${domain}"
          config      = config
          root_domain = domain
        }
      ]
    ]
  )
  # We then iterate the list of objects containing the information we need for the aws_route53_record resources, and
  # turn them into a giant map for foreaching.
  public_subdomains = {
    for domain_pair in local.public_subdomains_pairs :
    domain_pair.name => {
      config      = domain_pair.config
      root_domain = domain_pair.root_domain
    }
  }

  # Build a map of objects representing the apex records to create.
  # First, we take the subdomains field on each domain and extract the information we need to create the
  # aws_route53_record resources. The output of this expression is a list of objects.
  public_apex_records = flatten(
    [
      for domain, zone in var.public_zones :
      [
        for record in lookup(zone, "apex_records", []) :
        {
          name    = domain
          type    = record.type
          ttl     = record.ttl
          records = record.records
        }
      ]
    ]
  )

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
