# Common variables for all AWS accounts
locals {
  # Centrally define all our AWS account IDs
  # NOTE: these are currently all set to the same account ID (for Gruntworks Phx DevOps AWS account) for easy testing,
  # but in real usage, each of these would be set to a different value!
  master_account_id   = "087285199408"
  security_account_id = "087285199408"
  stage_account_id    = "087285199408"
  prod_account_id     = "087285199408"

  # Send all CloudTrail logs from all child accounts to this S3 bucket
  cloudtrail_s3_bucket_name = "ref-arch-lite-security-logs"

  # Centrally manage all the VPC CIDR blocks
  stage_cidr_block = "10.0.0.0/16"
  prod_cidr_block  = "10.2.0.0/16"

  # Default AWS region for API calls
  default_region = "eu-west-1"
}