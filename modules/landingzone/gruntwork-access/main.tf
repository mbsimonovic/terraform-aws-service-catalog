terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ----------------------------------------------------------------------------------------------------------------------
# CREATE THE IAM ROLE
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "gruntwork_access_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.gruntwork_access_role.json
  tags               = var.tags
}

# ----------------------------------------------------------------------------------------------------------------------
# GRANT PERMISSIONS TO ASSUME THE IAM ROLE
# An assume role policy that allows the IAM role to be assumed by (a) the Gruntwork team and (b) resources in the
# security account. Both of these are necessary for Gruntwork to do a Reference Architecture deployment.
# ----------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "gruntwork_access_role" {
  # Allow the Gruntwork team to use this IAM role. This is how Gruntwork can securely access customer accounts without
  # having to create/share/maintain separate credentials for each one.
  statement {
    sid     = "GrantGruntworkTeamAccess"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = [var.gruntwork_aws_account_id]
      type        = "AWS"
    }

    dynamic "condition" {
      # The contents of the list don't matter; all that matters is that there is one item in it or not.
      for_each = var.require_mfa ? ["once"] : []

      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }

  # Allow the security account to use this IAM role. To deploy the Reference Architecture, the Gruntwork team deploys an
  # EC2 instance in the security account, and that instance assumes this IAM role to get access to all the other child
  # accounts and bootstrap the deployment process.
  dynamic "statement" {
    # The contents of the list don't matter; all that matters is that there is one item in it or not.
    for_each = var.grant_security_account_access ? ["once"] : []

    content {
      sid     = "GrantSecurityAccountAccess"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        identifiers = ["arn:aws:iam::${var.security_account_id}:root"]
        type        = "AWS"
      }
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# ATTACH PERMISSIONS TO THE IAM ROLE
# To deploy the Reference Architecture, Gruntwork needs admin permissions in each child account
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "grant_gruntwork_admin_access" {
  role       = aws_iam_role.gruntwork_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/${var.managed_policy_name}"
}

