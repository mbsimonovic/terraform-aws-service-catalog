terraform {
  # source = "git::git@github.com:gruntwork-io/infrastructure-modules.git//modules/services/static-website?ref=v0.0.1"
  source = "../static-website"
}

inputs = {
  aws_region                    = "us-east-1"
  aws_account_id                = "087285199408"
  website_domain_name           = "acme-stage-static.gruntwork.in"
  create_route53_entry          = true
  terraform_state_region        = "us-east-1"
  terraform_state_s3_bucket     = "rho-test-static-website_state"
  terraform_state_aws_region    = "us-east-1"
  terraform_state_aws_s3_bucket = "rho-test-static-website"
  acm_certificate_domain_name   = "*.gruntwork.in"
  hosted_zone_id                = "Z1Y6DCUKW424UT"

# CloudFront cache settings
# Defaults, so no need to explicitly say
#  default_ttl = 30
#  max_ttl     = 60
#  min_ttl     = 0

# Only set this to true if, when running 'terragrunt destroy,' you want to delete the contents of the S3 buckets that
# store the website, redirects, and access logs. Note that you must set this to true and run 'terragrunt apply' FIRST,
# before running 'destroy'!
  force_destroy = true
}
