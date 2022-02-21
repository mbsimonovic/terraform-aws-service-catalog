# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN S3 BUCKET
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6, < 4.0"
    }
  }
}

provider "aws" {
  # If we are setting up replication, use the region the user provided. Otherwise, if we're not setting up replication,
  # and the user hasn't specified a region, pick a region just so the provider block doesn't error out (the provider
  # won't be used, so the region doesn't matter in this case)
  alias  = "replica"
  region = var.replica_bucket == null && var.replica_region == null ? "us-east-1" : var.replica_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE PRIMARY BUCKET
# ---------------------------------------------------------------------------------------------------------------------
module "s3_bucket_primary" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/private-s3-bucket?ref=v0.59.0"

  name = var.primary_bucket

  # Object versioning
  enable_versioning = var.enable_versioning
  mfa_delete        = var.mfa_delete

  # Access logging
  access_logging_enabled = var.access_logging_bucket != null
  access_logging_bucket  = var.access_logging_bucket
  access_logging_prefix  = var.access_logging_prefix

  # Replication
  replication_enabled = var.replica_bucket != null
  replication_role    = var.replication_role
  replication_rules   = var.replication_rules

  # CORS
  cors_rules = var.cors_rules

  # Lifecycle Rules
  lifecycle_rules = var.lifecycle_rules

  bucket_policy_statements = var.bucket_policy_statements
  bucket_ownership         = var.bucket_ownership
  enable_sse               = var.enable_sse
  kms_key_arn              = var.bucket_kms_key_arn
  sse_algorithm            = var.bucket_sse_algorithm
  tags                     = var.tags
  force_destroy            = var.force_destroy_primary
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET TO STORE ACCESS LOGS
# ---------------------------------------------------------------------------------------------------------------------
module "s3_bucket_logs" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/private-s3-bucket?ref=v0.59.0"

  create_resources = var.access_logging_bucket != null

  name                     = var.access_logging_bucket
  acl                      = "log-delivery-write"
  bucket_policy_statements = var.access_logging_bucket_policy_statements
  enable_versioning        = var.enable_versioning
  lifecycle_rules          = var.access_logging_bucket_lifecycle_rules
  mfa_delete               = var.mfa_delete
  sse_algorithm            = "AES256" # For access logging buckets, only AES256 encryption is supported
  bucket_ownership         = var.access_logging_bucket_ownership
  tags                     = var.tags
  force_destroy            = var.force_destroy_logs
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET FOR REPLICATION
# ---------------------------------------------------------------------------------------------------------------------
module "s3_bucket_replica" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/private-s3-bucket?ref=v0.59.0"

  providers = {
    aws = aws.replica
  }

  create_resources         = var.replica_bucket != null && var.replica_bucket_already_exists == false
  name                     = var.replica_bucket
  enable_versioning        = var.enable_versioning
  lifecycle_rules          = var.replica_bucket_lifecycle_rules
  mfa_delete               = var.mfa_delete
  bucket_policy_statements = var.replica_bucket_policy_statements
  bucket_ownership         = var.replica_bucket_ownership
  enable_sse               = var.replica_enable_sse
  sse_algorithm            = var.replica_sse_algorithm
  tags                     = var.tags
  force_destroy            = var.force_destroy_replica
}
