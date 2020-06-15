
provider "aws" {
  region = var.aws_region
}

module "asg" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/alb?ref=v1.0.8"
  source = "../../../../modules/services/asg-service"

  name = var.name

  instance_type = "t3.small"
  ami = var.ami

  min_size = 2
  max_size = 3
  desired_capacity = 2
  min_elb_capacity = 2

  server_port = 80
  alb_security_groups = []

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids

  vpn_security_group_ids = [] // TODO ?? allow ALL or allow cidr_blocks ?
  // output from vpn, [data.terraform_remote_state.openvpn_server.outputs.security_group_id]

  health_check_protocol = "HTTP"
  health_check_path = "/"

  create_route53_entry = false // creates the dns A for cname

  alb_hosted_zone_id = module.alb.alb_hosted_zone_id
  alb_listener_rule_configs = [
    {
      port     = 80
      path     = "/*"
      priority = 90
    }
  ]

  alb_listener_arn = module.alb.listener_arns[80] // alb_listener_rule_configs[0].port

  hosted_zone_id = ""

  iam_users_defined_in_separate_account = false
  init_script_path = ""
  is_internal_alb = false

  key_pair_name = "marina"
  mgmt_vpc_name = "" //??
  original_alb_dns_name = ""
  using_end_to_end_encryption = false

  user_data = <<-EOF
              #!/bin/bash
              echo "=========== marina =================================="
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
}

module "vpc" {
  source = "../../../../modules/networking/vpc"

  aws_region           = var.aws_region
  cidr_block           = "10.0.0.0/16"
  num_nat_gateways     = 1
  vpc_name             = var.name
  create_flow_logs     = false
}

module "alb" {
  source = "../../../../modules/networking/alb"

  alb_name = "marina-testing"
  is_internal_alb = false // ???
  num_days_after_which_archive_log_data = 0
  num_days_after_which_delete_log_data = 0

  http_listener_ports = [80]

  vpc_id = module.vpc.vpc_id
  vpc_subnet_ids = module.vpc.public_subnet_ids
}
