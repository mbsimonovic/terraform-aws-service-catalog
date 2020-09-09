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
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that may have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.26"

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
  source = "git::git@github.com:gruntwork-io/package-messaging.git//modules/sns?ref=v0.3.4"

  create_resources = var.create_resources

  name                      = var.name
  display_name              = var.display_name
  allow_publish_accounts    = var.allow_publish_accounts
  allow_subscribe_accounts  = var.allow_subscribe_accounts
  allow_subscribe_protocols = var.allow_subscribe_protocols
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL SNS → SLACK INTEGRATION
# ---------------------------------------------------------------------------------------------------------------------

module "sns_to_slack" {
  # TODO: Update to released version
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/sns-to-slack?ref=v0.22.2"

  create_resources = var.create_resources && var.slack_webhook_url != null

  lambda_function_name = var.name
  sns_topic_arn        = module.sns_topic.topic_arn
  slack_webhook_url    = var.slack_webhook_url
}
