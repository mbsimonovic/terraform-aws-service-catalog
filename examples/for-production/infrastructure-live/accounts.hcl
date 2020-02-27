# Common variables for all AWS accounts
inputs {
  # Centrally define all our AWS account IDs
  master_account_id   = "111111111111"
  security_account_id = "222222222222"
  stage_account_id    = "333333333333"
  prod_account_id     = "444444444444"

  # Centrally manage all the VPC CIDR blocks
  stage_cidr_block = "10.0.0.0/16"
  prod_cidr_block  = "10.0.10.0/16"

  # Default AWS region for API calls
  default_region = "eu-west-1"
}