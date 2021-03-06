# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AND MANAGE AMAZON ELASTIC CONTAINER REGISTRY REPOS
# Each ECR repo can be used for managing multiple Docker images with immutable tags.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ECR REPOS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecr_repository" "repos" {
  for_each = local.repositories_with_defaults

  name                 = each.key
  image_tag_mutability = each.value.image_tag_mutability
  tags                 = each.value.tags

  image_scanning_configuration {
    scan_on_push = each.value.enable_automatic_image_scanning
  }

  dynamic "encryption_configuration" {
    # The contents of the list do not matter as it is only used to determine whether or not to include the subblock.
    for_each = each.value.encryption_config != null ? ["once"] : []
    content {
      encryption_type = each.value.encryption_config.encryption_type
      kms_key         = each.value.encryption_config.kms_key
    }
  }
}

locals {
  # Construct the configuration of ECR repositories that combine the raw user input with the configured defaults.
  repositories_with_defaults = {
    for repo_name, user_config in var.repositories :
    repo_name => {
      external_account_ids_with_read_access  = lookup(user_config, "external_account_ids_with_read_access", var.default_external_account_ids_with_read_access)
      external_account_ids_with_write_access = lookup(user_config, "external_account_ids_with_write_access", var.default_external_account_ids_with_write_access)
      enable_automatic_image_scanning        = lookup(user_config, "enable_automatic_image_scanning", var.default_automatic_image_scanning)
      encryption_config                      = lookup(user_config, "encryption_config", var.default_encryption_config)
      image_tag_mutability                   = lookup(user_config, "image_tag_mutability", var.default_image_tag_mutability)
      lifecycle_policy_rules                 = lookup(user_config, "lifecycle_policy_rules", var.default_lifecycle_policy_rules)
      tags = merge(
        lookup(user_config, "tags", {}),
        var.global_tags,
      )
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE EXTERNAL ACCOUNTS ABILITY TO PUSH AND PULL IMAGES
# ---------------------------------------------------------------------------------------------------------------------

locals {
  repositories_with_lifecycle_rules = {
    for repo_name, repo in local.repositories_with_defaults :
    repo_name => repo if length(repo.lifecycle_policy_rules) > 0
  }
  # We first get the actual external account access list by implementing the logic to use the default value when the map
  # value is null.
  repositories_to_external_access = {
    for repo_name, repo in local.repositories_with_defaults :
    repo_name => {
      external_account_ids_with_read_access  = repo.external_account_ids_with_read_access != null ? repo.external_account_ids_with_read_access : var.default_external_account_ids_with_read_access
      external_account_ids_with_write_access = repo.external_account_ids_with_write_access != null ? repo.external_account_ids_with_write_access : var.default_external_account_ids_with_write_access
    }
  }

  # We then filter out all the repos that have no external access configured.
  repositories_with_external_access = {
    for repo_name, repo in local.repositories_to_external_access :
    repo_name => repo if length(repo.external_account_ids_with_read_access) > 0 || length(repo.external_account_ids_with_write_access) > 0
  }

  # The list of IAM policy actions for write access
  iam_write_access_policies = [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:GetRepositoryPolicy",
    "ecr:DescribeRepositories",
    "ecr:ListImages",
    "ecr:DescribeImages",
    "ecr:BatchGetImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage",
  ]

  # The list of IAM policy actions for read access
  iam_read_access_policies = [
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:BatchCheckLayerAvailability",
  ]
}

resource "aws_ecr_repository_policy" "external_account_access" {
  for_each   = local.repositories_with_external_access
  repository = aws_ecr_repository.repos[each.key].name
  policy     = data.aws_iam_policy_document.external_account_access[each.key].json
}

data "aws_iam_policy_document" "external_account_access" {
  for_each = local.repositories_with_external_access

  dynamic "statement" {
    # Ideally, this wouldn't be a dynamic block, but without it, if the principal list is empty,
    # Terraform will keep trying to apply the policy until it times out. Therefore, we guard
    # against this outcome by checking that the principal list has at least one value.
    for_each = length(each.value.external_account_ids_with_read_access) > 0 ? ["noop"] : []

    content {
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = formatlist("arn:aws:iam::%s:root", each.value.external_account_ids_with_read_access)
      }

      actions = local.iam_read_access_policies
    }
  }

  dynamic "statement" {
    # Ideally, this wouldn't be a dynamic block, but without it, if the principal list is empty,
    # Terraform will keep trying to apply the policy until it times out. Therefore, we guard
    # against this outcome by checking that the principal list has at least one value.
    for_each = length(each.value.external_account_ids_with_write_access) > 0 ? ["noop"] : []

    content {
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = formatlist("arn:aws:iam::%s:root", each.value.external_account_ids_with_write_access)
      }

      actions = local.iam_write_access_policies
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD LIFECYCLE RULES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = local.repositories_with_lifecycle_rules
  repository = aws_ecr_repository.repos[each.key].name
  policy     = jsonencode(each.value.lifecycle_policy_rules)
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE CROSS REGION REPLICATION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecr_replication_configuration" "this" {
  count = length(var.replication_regions) > 0 ? 1 : 0
  replication_configuration {
    rule {

      dynamic "destination" {
        for_each = var.replication_regions
        content {
          region      = destination.value
          registry_id = data.aws_caller_identity.current.account_id
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
