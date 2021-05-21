# ----------------------------------------------------------------------------------------------------------------
# This is the root configuration for infrastructure-live. Its purpose is to:
#
#   - generate a provider block to configure the Terraform provider for AWS
#   - generate a remote state block for storing state in S3
#   - define a minimal set of global inputs that may be needed by any file
#
# Each module within infrastructure-live includes this file.
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
# LOAD COMMON VARIABLES
# ----------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract commonly used variables for easy acess
  name_prefix  = local.common_vars.locals.name_prefix
  account_name = local.account_vars.locals.account_name
  account_id   = local.common_vars.locals.accounts[local.account_name]
  aws_region   = local.region_vars.locals.aws_region
}

# ----------------------------------------------------------------------------------------------------------------
# GENERATED PROVIDER BLOCK
# ----------------------------------------------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}
# ----------------------------------------------------------------------------------------------------------------
# GENERATED REMOTE STATE BLOCK
# ----------------------------------------------------------------------------------------------------------------
# Generate the Terraform remote state block for storing state in S3
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "${local.name_prefix}-${local.account_name}-${local.aws_region}-tf-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
# ----------------------------------------------------------------------------------------------------------------
# DEFAULT INPUTS
# ----------------------------------------------------------------------------------------------------------------
inputs = {
  # Many modules require these two inputs, so we set them globally here to keep all the child terragrunt.hcl
  # files more DRY
  aws_account_id = local.account_id
  aws_region     = local.aws_region
  name_prefix    = local.common_vars.locals.name_prefix
}
