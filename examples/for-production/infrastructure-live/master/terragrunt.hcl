locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  # Automatically load region-level variables.
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Common variables used across this AWS account
  common_inputs = {
    aws_account_id = local.account_vars.locals.master_account_id
    aws_region     = local.region_vars.locals.aws_region
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region_vars.locals.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.common_inputs.aws_account_id}"]
}
EOF
}

# Generate the Terraform backend config to store state in S3
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "gruntwork-ref-arch-lite-master-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.account_vars.locals.default_region
    dynamodb_table = "terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# The default set of inputs for all child accounts
inputs = merge(local.region_vars.locals, local.common_inputs)