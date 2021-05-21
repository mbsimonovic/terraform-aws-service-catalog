# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY LAMBDA FUNCTION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"

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

  source_path     = var.source_path
  skip_zip        = var.skip_zip
  zip_output_path = var.zip_output_path

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

module "lambda_alarm" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/lambda-alarms?ref=v0.26.2"

  function_name        = module.lambda_function.function_name
  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  comparison_operator = var.comparison_operator
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = var.datapoints_to_alarm
  metric_name         = var.metric_name
  period              = var.period
  statistic           = var.statistic
  threshold           = var.threshold
}
