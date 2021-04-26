# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY LAMBDA FUNCTION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # We are using some features that are only available on Terraform >= 0.13.0
  required_version = ">= 0.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.68"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

module "lambda_function" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda//modules/lambda?ref=v0.10.1"

  create_resources = var.create_resources

  name              = var.name
  description       = var.description
  enable_versioning = var.enable_versioning

  source_path      = var.source_path
  skip_zip         = var.skip_zip
  zip_output_path  = var.zip_output_path
  source_code_hash = var.source_code_hash

  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version

  image_uri = var.image_uri

  runtime                        = var.runtime
  handler                        = var.handler
  memory_size                    = var.memory_size
  environment_variables          = var.environment_variables
  kms_key_arn                    = var.kms_key_arn
  timeout                        = var.timeout
  layers                         = var.layers
  reserved_concurrent_executions = var.reserved_concurrent_executions

  lambda_role_permissions_boundary_arn = var.lambda_role_permissions_boundary_arn
  assume_role_policy                   = var.assume_role_policy

  run_in_vpc                   = var.run_in_vpc
  vpc_id                       = var.vpc_id
  mount_to_file_system         = var.mount_to_file_system
  file_system_access_point_arn = var.file_system_access_point_arn
  file_system_mount_path       = var.file_system_mount_path
  subnet_ids                   = var.subnet_ids
  should_create_outbound_rule  = var.should_create_outbound_rule

  dead_letter_target_arn = var.dead_letter_target_arn

  entry_point       = var.entry_point
  command           = var.command
  working_directory = var.working_directory

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# SCHEDULE THE LAMBDA FUNCTION TO RUN IF NEEDED
# ---------------------------------------------------------------------------------------------------------------------

module "scheduled_job" {
  source   = "git::git@github.com:gruntwork-io/terraform-aws-lambda//modules/scheduled-lambda-job?ref=v0.10.1"
  for_each = var.schedule_expression == null ? toset([]) : toset(["once"])

  create_resources = var.create_resources

  lambda_function_name = module.lambda_function.function_name
  lambda_function_arn  = module.lambda_function.function_arn
  schedule_expression  = var.schedule_expression
  namespace            = var.namespace
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH METRIC ALARM
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_failure_alarm" {
  # Dynamic way to choose the correct topic based on if a new one was created or passed as a variable
  for_each = local.should_create_sns_topic ? {
    for topic in aws_sns_topic.failure_topic : topic.name => topic.arn
    } : {
    for topic in [var.alert_on_failure_sns_topic] : topic.name => topic.arn
  }

  alarm_name                = "${module.lambda_function.function_name}-failure-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  datapoints_to_alarm       = 1
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "0.0"
  alarm_description         = "Indicates that the lambda function ${module.lambda_function.function_name} failed"
  insufficient_data_actions = []

  dimensions = {
    FunctionName = module.lambda_function.function_name
  }

  alarm_actions = [each.value]
  ok_actions    = [each.value]
}

locals {
  # We only create a new topic if the alert_on_failure_sns_topic variable is null
  should_create_sns_topic = var.alert_on_failure_sns_topic == null ? true : false

  sns_failure_topic_name = (
    local.should_create_sns_topic
    ? "${module.lambda_function.function_name}-failures"
    : var.alert_on_failure_sns_topic.name
  )
}

resource "aws_sns_topic" "failure_topic" {
  # Using for_each to decide if we should create the SNS Topic or not.
  for_each = local.should_create_sns_topic ? { create = true } : {}

  name = local.sns_failure_topic_name
}
