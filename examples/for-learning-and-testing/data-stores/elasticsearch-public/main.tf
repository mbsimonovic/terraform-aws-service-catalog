# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.35"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/elasticsearch?ref=v1.2.3"
  source = "../../../../modules/data-stores/elasticsearch"

  # Cluster Configurations
  domain_name            = var.domain_name
  elasticsearch_version  = "7.7"
  instance_type          = "t3.small.elasticsearch"
  instance_count         = 1
  volume_type            = "gp2"
  volume_size            = 10
  zone_awareness_enabled = false

  # Network Configurations

  # This example creates a publicly accessible cluster to make testing easier. In prod, you will most likely want to set is_public to false and only allow access from within your VPC.
  is_public          = true
  iam_principal_arns = [data.aws_caller_identity.current.arn]

  # Since this is just an example, we don't deploy any CloudWatch resources in order to make it faster to deploy, however in
  # production you'll probably want to enable this feature.
  enable_cloudwatch_alarms = false

  # Encryption config.
  # Since this is just an example, we use the default service KMS key when encryption at rest is
  # enabled. However, in production, you will want to configure a dedicated encryption KMS key.
  enable_encryption_at_rest = var.enable_encryption_at_rest
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}