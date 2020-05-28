# Common variables for all AWS accounts
locals {
  # Centrally define all our AWS account IDs
  # NOTE: these are currently all set to the same account ID (for Gruntworks Phx DevOps AWS account) for easy testing,
  # but in real usage, each of these would be set to a different value!
  account_ids = {
    master   = "087285199408"
    security = "087285199408"
    shared   = "087285199408"
    dev      = "087285199408"
    stage    = "087285199408"
    prod     = "087285199408"
  }

  # Centrally define all domain names  
  domain_names = {
    shared = "refarch-sbox-shared-gruntwork.com"
    dev    = "refarch-sbox-dev-gruntwork.com"
    stage  = "refarch-sbox-stage-gruntwork.com"
    prod   = "refarch-sbox-prod-gruntwork.com"
  }

  # Prefix resources with this name 
  name_prefix = "gw-ra-service-catalog"

  # Send all CloudTrail logs from all child accounts to this S3 bucket
  cloudtrail_s3_bucket_name = "ref-arch-lite-security-logs"

  # Use the KMS key created in the security account
  cloudtrail_kms_key_arn = "TODO: fill me in after deploying the security account"

  # Centrally manage all the VPC CIDR blocks
  vpc_cidr_blocks = {
    shared = "10.0.0.0/16"
    dev    = "10.2.0.0/16"
    stage  = "10.4.0.0/16"
    prod   = "10.6.0.0/16"
  }

  # Default AWS region for API calls
  default_region = "eu-west-1"

  # List of known CIDR blocks that correspond to organization office locations. Administrative access (e.g., VPN, SSH,
  # etc) will be limited to these source CIDRs.
  office_cidr_blocks = [
    "1.2.3.0/24",
  ]
}
