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
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/public-static-website?ref=v1.2.3"
  source = "../../../../modules/services/public-static-website"

  website_domain_name           = var.website_domain_name
  acm_certificate_domain_name   = var.acm_certificate_domain_name
  base_domain_name              = var.base_domain_name
  base_domain_name_tags         = var.base_domain_name_tags

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
  acl          = "public-read"

  depends_on = [module.static_website]
}
