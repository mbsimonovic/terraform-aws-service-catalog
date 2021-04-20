# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A LAMBDA FUNCTION
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "lambda_function" {
  source      = "../../../../modules/services/lambda"
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

  alert_on_failure_sns_topic = aws_sns_topic.failure_topic
}

resource "aws_sns_topic" "failure_topic" {
  name = "example-failure-sns-topic"
}
