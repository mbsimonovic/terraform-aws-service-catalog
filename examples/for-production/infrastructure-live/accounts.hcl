# Common variables for all AWS accounts
inputs = {
  # Centrally define all our AWS account IDs
  # NOTE: these are currently all set to the same account ID (for Gruntworks Phx DevOps AWS account) for easy testing,
  # but in real usage, each of these would be set to a different value!
  master_account_id   = "087285199408"
  security_account_id = "087285199408"
  stage_account_id    = "087285199408"
  prod_account_id     = "087285199408"

  # Centrally manage all the VPC CIDR blocks
  stage_cidr_block = "10.0.0.0/16"
  prod_cidr_block  = "10.0.10.0/16"

  # Default AWS region for API calls
  default_region = "eu-west-1"
}