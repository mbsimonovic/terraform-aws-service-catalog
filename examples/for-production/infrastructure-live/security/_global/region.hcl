# Modules in the account _global folder don't live in any specific AWS region, but you still have to send the API calls
# to _some_ AWS region, so here we pick an arbitrary region to use for those API calls.
locals {
  aws_region = read_terragrunt_config(find_in_parent_folders("accounts.hcl")).locals.default_region
}