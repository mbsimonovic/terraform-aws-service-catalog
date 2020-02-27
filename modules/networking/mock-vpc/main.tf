# ---------------------------------------------------------------------------------------------------------------------
# A MOCK VERSION OF A VPC MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = "~> 2.6"
  }
}

resource "random_pet" "example" {
  keepers = {
    vpc_name = var.vpc_name
  }

  prefix = "vpc"
}