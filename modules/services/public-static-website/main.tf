# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A STATIC WEBSITE IN AN S3 BUCKET AND DEPLOY CLOUDFRONT AS A CDN IN FRONT OF IT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE TERRAFORM AND PROVIDER REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE STATIC WEBSITE
# ---------------------------------------------------------------------------------------------------------------------

module "static_website" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-static-assets.git//modules/s3-static-website?ref=v0.11.0"

  website_domain_name   = var.website_domain_name
  index_document        = var.index_document
  error_document        = var.error_document
  base_domain_name      = var.base_domain_name
  base_domain_name_tags = var.base_domain_name_tags
  hosted_zone_id        = var.hosted_zone_id
  custom_tags           = var.custom_tags

  force_destroy_website            = var.force_destroy
  force_destroy_redirect           = var.force_destroy
  force_destroy_access_logs_bucket = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CLOUDFRONT WEB DISTRIBUTION
# ---------------------------------------------------------------------------------------------------------------------

module "cloudfront" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-static-assets.git//modules/s3-cloudfront?ref=v0.11.0"

  bucket_name                 = var.website_domain_name
  s3_bucket_is_public_website = true
  bucket_website_endpoint     = module.static_website.website_bucket_endpoint

  index_document = var.index_document

  min_ttl     = var.min_ttl
  max_ttl     = var.max_ttl
  default_ttl = var.default_ttl

  create_route53_entries = var.create_route53_entry
  domain_names           = var.create_route53_entry ? [var.website_domain_name] : []
  base_domain_name       = var.base_domain_name
  base_domain_name_tags  = var.base_domain_name_tags
  hosted_zone_id         = var.hosted_zone_id
  custom_tags            = var.custom_tags

  # If var.create_route53_entry is false, the aws_acm_certificate data source won't be created. Ideally, we'd just use
  # a conditional to only use that data source if var.create_route53_entry is true, but Terraform's conditionals are
  # not short-circuiting, so both branches would be evaluated. Therefore, we use this silly trick with "join" to get
  # back an empty string if the data source was not created.
  acm_certificate_arn = join(",", data.aws_acm_certificate.cert.*.arn)

  force_destroy_access_logs_bucket = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# FIND THE ACM CERTIFICATE
# If var.create_route53_entry is true, we need a custom TLS cert for our custom domain name. Here, we look for a
# cert issued by Amazon's Certificate Manager (ACM) for the domain name var.acm_certificate_domain_name.
# ---------------------------------------------------------------------------------------------------------------------

# Note that ACM certs for CloudFront MUST be in us-east-1!
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

data "aws_acm_certificate" "cert" {
  count    = var.create_route53_entry ? 1 : 0
  provider = aws.east

  domain   = var.acm_certificate_domain_name
  statuses = ["ISSUED"]
}
