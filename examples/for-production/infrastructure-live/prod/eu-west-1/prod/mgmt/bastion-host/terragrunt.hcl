terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/bastion-host?ref=master"
}

include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../../networking/vpc"
}

dependencies {
  paths = ["../../../../_global/account-baseline"]
}

locals {
  # Automatically load common variables shared across all accounts
  common_vars  = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

inputs = {
  vpc_id      = dependency.vpc.outputs.vpc_id
  subnet_id   = dependency.vpc.outputs.public_subnet_ids[0]
  ami         = ami-abcd1234"

  # Access to the bastion should be limited to specific, known CIDR blocks
  allow_ssh_from_cidr_list = ["1.2.3.0/24"]

  # TODO: Set to true, and configure external_account_ssh_grunt_role_arn
  enable_ssh_grunt         = false

  # TODO: Set up an SNS topic for alarms and use a dependency to pass it in
  # alarms_sns_topic_arn   = []

  # TODO: We'd normally use a dependency block to pull in the hosted zone ID, but we haven't converted the route 53
  # modules to the new service catalog format yet, so for now, we just hard-code the ID.
  hosted_zone_id           = "Z2AJ7S3R6G9UYJ"
  domain_name              = "gruntwork.in"
}
