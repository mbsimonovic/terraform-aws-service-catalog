provider "aws" {
  region = var.aws_region
}

module "vpc_app" {
  source = "../../../../modules/networking/vpc-app"

  aws_account_id   = var.aws_account_id
  aws_region       = var.aws_region
  cidr_block       = var.cidr_block
  num_nat_gateways = var.num_nat_gateways
  vpc_name         = var.vpc_name

  kms_key_user_iam_arns = var.kms_key_user_iam_arns
}
