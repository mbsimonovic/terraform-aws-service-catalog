resource "random_pet" "example" {
  keepers = {
    vpc_name = var.vpc_name
  }

  prefix = "vpc"
}