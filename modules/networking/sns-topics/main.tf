# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE SNS TOPICS
# When you want to send a notification on an event, it's useful to have a Simple Notification Service (SNS) Topic to
# which a message can be published. Operators can then manually subscribe to receive email or text message
# notifications when various events take place.
#
# IMPORTANT: You will not receive any notification that an SNS Topic has received a message unless you manually
# subscribe an email address or other endpoint to that SNS Topic.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE SNS TOPIC
# ---------------------------------------------------------------------------------------------------------------------

module "sns_topic" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-messaging.git//modules/sns?ref=v0.7.1"

  create_resources = var.create_resources

  name                      = var.name
  display_name              = var.display_name
  allow_publish_accounts    = var.allow_publish_accounts
  allow_publish_services    = var.allow_publish_services
  allow_subscribe_accounts  = var.allow_subscribe_accounts
  allow_subscribe_protocols = var.allow_subscribe_protocols
  kms_master_key_id         = var.kms_master_key_id
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL SNS → SLACK INTEGRATION
# ---------------------------------------------------------------------------------------------------------------------

module "sns_to_slack" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/sns-to-slack?ref=v0.30.0"

  create_resources = var.create_resources && var.slack_webhook_url != null

  lambda_function_name = var.name
  sns_topic_arn        = module.sns_topic.topic_arn
  slack_webhook_url    = var.slack_webhook_url
}
