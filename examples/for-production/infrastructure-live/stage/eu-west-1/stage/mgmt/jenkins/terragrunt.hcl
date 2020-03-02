# It's a bit silly to deploy Jenkins in all these accounts, but we're just using this as a dummy test case for now
terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/jenkins?ref=ref-arch-lite"
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

inputs = {
  name          = "ref-arch-lite-jenkins"
  ami           = "ami-abcd1234"
  instance_type = "t2.micro"
  memory        = "512m"

  vpc_id            = dependency.vpc.outputs.vpc_id
  jenkins_subnet_id = dependency.vpc.outputs.private_app_subnet_ids[0]
  alb_subnet_ids    = dependency.vpc.outputs.public_subnet_ids

  keypair_name               = "jim-brikman"
  allow_ssh_from_cidr_blocks = ["0.0.0.0/0"]
  enable_ssh_grunt           = false

  is_internal_alb                      = false
  allow_incoming_http_from_cidr_blocks = ["0.0.0.0/0"]

  # We'd normally use a dependency block to pull in the hosted zone ID, but we haven't converted the route 53 modules
  # to the new service catalog format yet, so for now, we just hard-code the ID.
  hosted_zone_id             = "Z2AJ7S3R6G9UYJ"
  domain_name                = "ref-arch-lite-jenkins-stage.gruntwork.in"
  acm_ssl_certificate_domain = "*.gruntwork.in"
}