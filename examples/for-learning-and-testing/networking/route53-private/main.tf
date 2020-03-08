# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE DNS ENTRIES USING ROUTE53
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
  region = "us-west-1"
}

module "route53-private" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/jenkins?ref=v1.0.8"
  source = "../../../../modules/networking/route53-private"

  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  vpc_name = var.vpc_name
  vpc_id   = var.vpc_id

  terraform_state_aws_region = var.terraform_state_aws_region
  terraform_state_s3_bucket  = var.terraform_state_s3_bucket

  internal_services_domain_name = var.internal_services_domain_name
}
