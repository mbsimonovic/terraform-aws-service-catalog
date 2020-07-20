
provider "aws" {
  region = var.aws_region
}

locals {
  server_port = 8080
}

module "asg" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/asg-service?ref=v1.0.8"
  source = "../../../../modules/services/asg-service"

  name = var.name

  instance_type = "t3.micro"
  ami           = var.ami

  min_size         = 2
  max_size         = 3
  desired_capacity = 2
  min_elb_capacity = 2

  server_port = local.server_port

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  health_check_protocol = "HTTP"
  health_check_path     = "/"

  create_route53_entry = false

  forward_listener_rules = {
    "root-route" = {
      path_patterns = ["/*"]
    }
  }

  listener_arns  = module.alb.listener_arns
  listener_ports = [80]

  key_pair_name = var.key_pair_name
}

module "alb" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/alb?ref=v1.2.3"
  source = "../../../../modules/networking/alb"

  alb_name = var.name

  // For public, user-facing services (i.e., those accessible from the public Internet), this should be set to false.
  is_internal_alb = false

  num_days_after_which_archive_log_data = 0
  num_days_after_which_delete_log_data  = 0

  // For testing, we are allowing ALL but for production, you should limit just for the servers you want to trust
  allow_inbound_from_cidr_blocks = ["0.0.0.0/0"]

  http_listener_ports = [80]

  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnet_ids.default.ids
}
