terraform {
  required_providers {
    # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
    aws = "~> 2.6"
  }
}

resource "random_pet" "example" {
  keepers = {
    vpc_name = var.vpc_name
  }

  prefix = "vpc"
}