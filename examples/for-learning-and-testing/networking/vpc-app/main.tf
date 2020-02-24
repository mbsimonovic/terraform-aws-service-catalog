provider "aws" {
  region = var.aws_region
}

module "vpc_app" {
  source = "../../../../modules/networking/vpc-app"

  aws_region       = var.aws_region
  cidr_block       = var.cidr_block
  num_nat_gateways = var.num_nat_gateways
  vpc_name         = var.vpc_name

  // Providing an Key avoids to create a new one every run,
  // this is good to avoid since each costs $1/month
  kms_key_arn =  data.aws_kms_key.kms_key.arn
}
