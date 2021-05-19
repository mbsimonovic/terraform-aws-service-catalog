# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A LAMBDA FUNCTION
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "lambda_function" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/lambda?ref=v1.0.8"
  source = "../../../../modules/services/lambda"

  name        = var.name
  description = "Executing some requests to the internet"

  # Notice how the source_path is set to python/build, which doesn't initially exist. That's because you need to run
  # the build process for the code before deploying it with Terraform. See README.md for instructions.
  source_path = "${path.module}/python/build"
  runtime     = "python3.8"
  memory_size = 128
  handler     = "src/index.handler"
  timeout     = 10
  tags = {
    Name = var.name
  }
  environment_variables = {
    PYTHONPATH = "/var/task/dependencies"
  }

  schedule_expression = "rate(1 minute)"

  # A pre existing SNS Topic. It will receive cloudwatch metric alarms
  alarm_sns_topic_arns = [aws_sns_topic.failure_topic.arn]
}

# A pre existing SNS Topic is not necessary. Here is just an example that a
# previously created topic can be used.
resource "aws_sns_topic" "failure_topic" {
  name = var.sns_topic_name
}
