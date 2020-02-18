resource "random_pet" "example" {
  keepers = {
    amm_id = var.ami_id
    vpc_id = var.vpc_id
  }

  prefix = "ami-"
}