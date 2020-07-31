# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ASG
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "asg" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/asg-service?ref=v1.0.8"
  source = "../../../../modules/services/asg-service"

  name = var.name

  instance_type = "t3.micro"
  ami           = var.ami
  ami_filters   = null

  min_size         = var.num_instances
  max_size         = var.num_instances
  desired_capacity = var.num_instances
  min_elb_capacity = var.num_instances

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  server_ports = {
    "default-http" = {
      server_port           = "8080"
      health_check_protocol = "HTTP"
      health_check_path     = "/"
    },
    "another-port" = {
      server_port           = "3000"
      health_check_protocol = "HTTP"
      health_check_path     = "/"
    }
  }

  forward_listener_rules = {
    "root-route" = {
      path_patterns = ["/*"]
    }
  }

  listener_arns  = module.alb.listener_arns
  listener_ports = local.listener_ports

  key_pair_name = var.key_pair_name

  cloud_init_parts = local.cloud_init

  create_route53_entry      = false
  enable_cloudwatch_metrics = false
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

  http_listener_ports = local.listener_ports

  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnet_ids.default.ids

  # We need to set this to true so it’s easier to run destroy on this example as part of automated tests, but you should NOT set this to true in prod!
  force_destroy = true
}

locals {
  cloud_init = {
    "hello-world-server" = {
      filename     = "hello-world-server"
      content_type = "text/x-shellscript"
      content      = data.template_file.user_data.rendered
    }
  }

  server_port    = 8080
  listener_ports = [80]
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")
}


