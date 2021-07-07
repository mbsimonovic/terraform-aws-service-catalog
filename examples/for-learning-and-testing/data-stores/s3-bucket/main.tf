# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE, SECURE S3 BUCKET WITH VERSIONING, ACCESS LOGGING AND CROSS-REGION REPLICATION ENABLED
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  region = var.replica_aws_region
  alias  = "replica"
}

module "s3_bucket" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/s3-bucket?ref=v1.0.8"
  source = "../../../../modules/data-stores/s3-bucket"

  primary_bucket        = var.primary_bucket
  access_logging_bucket = var.access_logging_bucket
  replica_bucket        = var.replica_bucket
  replica_region        = var.replica_aws_region

  enable_versioning = var.enable_versioning
  mfa_delete        = var.mfa_delete

  # Grant read and write access to the current IAM user running this module
  bucket_policy_statements = {
    AllowCurrentUserReadWriteAccess = {
      effect = "Allow"
      actions = [
        "s3:Get*",
        "s3:List*",
        "s3:Put*"
      ]
      principals = {
        AWS = [data.aws_caller_identity.current.arn]
      }
    }
  }

  # Configure replication to another region
  replication_role = aws_iam_role.replication.arn
  replication_rules = {
    ExampleConfig = {
      prefix                            = "config/"
      status                            = "Enabled"
      destination_bucket                = "arn:aws:s3:::${var.replica_bucket}"
      destination_storage_class         = "STANDARD"
      source_selection_criteria_enabled = true
      destination_replica_kms_key_id    = aws_kms_key.replica.arn
    }
  }

  # To make it easier to test, we force destroy the buckets even when they're not empty.
  # In production, you'll likely want to retain the access logs bucket, for audit log purposes.
  force_destroy_primary = true
  force_destroy_logs    = true
  force_destroy_replica = true
}

# ---------------------------------------------------------------------------------------------------------------------
# FETCH INFORMATION ABOUT THE CURRENT USER
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# GRANT PRIMARY BUCKET ABILITY TO REPLICATE OBJECTS TO REPLICATION BUCKET
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name               = "s3-bucket-replication-${var.primary_bucket}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetReplicationConfiguration",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold"
    ]
    resources = [
      "arn:aws:s3:::${var.primary_bucket}",
      "arn:aws:s3:::${var.primary_bucket}/*"
    ]
  }
  statement {
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:GetObjectVersionTagging"]
    resources = ["arn:aws:s3:::${var.replica_bucket}/*"]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_key.default_aws_s3_key.arn]
    condition {
      test     = "StringLike"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
      variable = "kms:ViaService"
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:aws:s3:::${var.primary_bucket}/*"]
    }
  }
  statement {
    actions   = ["kms:Encrypt"]
    resources = [aws_kms_key.replica.arn]
    condition {
      test     = "StringLike"
      values   = ["s3.${var.replica_aws_region}.amazonaws.com"]
      variable = "kms:ViaService"
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:aws:s3:::${var.replica_bucket}/*"]
    }
  }
}

resource "aws_iam_policy" "replication" {
  name = "s3-bucket-replication-${var.primary_bucket}"

  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_policy_attachment" "replication" {
  name       = "s3-bucket-replication-${var.primary_bucket}"
  roles      = [aws_iam_role.replication.name]
  policy_arn = aws_iam_policy.replication.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE KMS KEY FOR ENCRYPTING OBJECTS IN REPLICATION BUCKET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "replica" {
  provider                = aws.replica
  deletion_window_in_days = 7
}