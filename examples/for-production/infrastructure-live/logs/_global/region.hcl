# Modules in the account _global folder don't live in any specific AWS region, but you still have to send the API calls
# to _some_ AWS region, so here we pick a default region to use for those API calls.
locals {
  aws_region = "us-west-2"
}
