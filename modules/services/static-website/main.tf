# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE A STATIC WEBSITE IN AN S3 BUCKET AND DEPLOY CLOUDFRONT AS A CDN IN FRONT OF IT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.26. TODO: explain why
  required_version = "~> 0.12.26"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE STATIC WEBSITE
# ---------------------------------------------------------------------------------------------------------------------

module "static_website" {
  source = "git::git@github.com:gruntwork-io/package-static-assets.git//modules/s3-static-website?ref=v0.5.3"

  website_domain_name = var.website_domain_name
  index_document      = var.index_document
  error_document      = var.error_document

  force_destroy_website            = var.force_destroy
  force_destroy_redirect           = var.force_destroy
  force_destroy_access_logs_bucket = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CLOUDFRONT WEB DISTRIBUTION
# ---------------------------------------------------------------------------------------------------------------------

module "cloudfront" {
  source = "git::git@github.com:gruntwork-io/package-static-assets.git//modules/s3-cloudfront?ref=v0.5.3"

  bucket_name                 = var.website_domain_name
  s3_bucket_is_public_website = true
  bucket_website_endpoint     = module.static_website.website_bucket_endpoint

  index_document     = var.index_document
  error_document_404 = var.error_document
  error_document_500 = var.error_document

  min_ttl     = var.min_ttl
  max_ttl     = var.max_ttl
  default_ttl = var.default_ttl

  create_route53_entries = var.create_route53_entry
  domain_names           = [var.website_domain_name]
  hosted_zone_id         = var.hosted_zone_id

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
  alias = "east"
  region = "us-east-1"

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"
}

data "aws_acm_certificate" "cert" {
  count = var.create_route53_entry ? 1 : 0
  provider = aws.east

  domain   = var.acm_certificate_domain_name
  statuses = ["ISSUED"]
}

# ---------------------------------------------------------------------------------------------------------------------
# UPLOAD AN EXAMPLE STATIC WEBSITE
# This is used solely to demonstrate that S3/CloudFront are working. When you go to deploy your real static content,
# you should remove this!
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_object" "example_website" {
  bucket       = var.website_domain_name
  key          = "index.html"
  source       = "${path.module}/example-website/index.html"
  content_type = "text/html"

  depends_on = [module.static_website]
}
