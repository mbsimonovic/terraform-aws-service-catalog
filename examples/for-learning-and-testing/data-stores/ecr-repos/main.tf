# ----------------------------------------------------------------------------------------------------------------------
# SETUP MULTIPLE ECR REPOSITORIES
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "ecr_repos" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/ecr-repos?ref=v1.0.8"
  source = "../../../../modules/data-stores/ecr-repos"

  repositories = var.repositories
  global_tags  = var.global_tags

  default_external_account_ids_with_read_access  = var.default_external_account_ids_with_read_access
  default_external_account_ids_with_write_access = var.default_external_account_ids_with_write_access
}