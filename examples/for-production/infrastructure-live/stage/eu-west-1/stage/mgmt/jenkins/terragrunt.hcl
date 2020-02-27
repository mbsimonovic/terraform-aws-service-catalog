# It's a bit silly to deploy Jenkins in all these accounts, but we're just using this as a dummy test case for now
terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/jenkins?ref=v0.0.1"
}

include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../../networking/mock-vpc"
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

  hosted_zone_id             = "Z2VWPXQ2IDW13E"
  domain_name                = "ref-arch-lite-jenkins-prod.gruntwork-sandbox.com"
  acm_ssl_certificate_domain = "*.gruntwork-sandbox.com"
}