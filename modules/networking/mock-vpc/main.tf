# ---------------------------------------------------------------------------------------------------------------------
# A MOCK VERSION OF A VPC MODULE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
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