# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A STATIC WEBSITE WITH A CLOUDFRONT DISTRIBUTION IN FRONT OF IT AS A CDN.
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

module "static_website" {
  source = "../../../../modules/services/public-static-website"

  website_domain_name           = var.website_domain_name
  acm_certificate_domain_name   = var.acm_certificate_domain_name
  hosted_zone_id                = var.hosted_zone_id

  # Default values
  # --------------
  # create_route53_entry          = true
  #
  # CloudFront cache settings
  # default_ttl                   = 30
  # max_ttl                       = 60
  # min_ttl                       = 0

  # Only set this to true if, when running 'terragrunt destroy,' you want to delete the contents of the S3 buckets that
  # store the website, redirects, and access logs. Note that you must set this to true and run 'terragrunt apply' FIRST,
  # before running 'destroy'!
  force_destroy                 = var.force_destroy
}

resource "aws_s3_bucket_object" "example_website" {
  bucket       = var.website_domain_name
  key          = "index.html"
  source       = "${path.module}/example-website/index.html"
  content_type = "text/html"

  depends_on = [module.static_website]
}
