# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A PUBLIC ALB, ROUTE 53 DNS ENTRY, S3 BUCKET FOR ACCESS LOGS, AND EXAMPLE WEBSERVER AS A BACKEND
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.aws_region
}

module "alb" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/alb?ref=v1.0.8"
  source = "../../../../modules/networking/alb"

  alb_name = var.alb_name

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets. In production,
  # you'll want to use a custom VPC, with your ALB in either a public or private subnet
  # depending upon whether it's internal or external facing
  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnet_ids.default.ids

  # For test purposes, we will only retain logs for a short period of time
  num_days_after_which_archive_log_data = 7
  num_days_after_which_delete_log_data  = 30

  is_internal_alb                = false
  allow_inbound_from_cidr_blocks = ["0.0.0.0/0"]
  https_listener_ports_and_acm_ssl_certs = [
    {
      port            = local.alb_entry_port
      tls_domain_name = "*.${data.aws_route53_zone.alb.name}"
    },
  ]

  # Configure a domain name for the ALB
  create_route53_entry = true
  hosted_zone_id       = data.aws_route53_zone.alb.zone_id
  domain_names         = ["${var.alb_subdomain}.${data.aws_route53_zone.alb.name}"]

  # To make it easier to test, we force destroy the access logs
  # In production, you'll want to retain the access logs irrespective
  # of the ALB, for audit log purposes
  force_destroy = true
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH SAMPLE EC2 INSTANCE AS WEBSERVER
# This is used as (a) an example of how to route traffic to servers
# using the ALB and (b) for automated testing.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "webserver" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.nano"
  vpc_security_group_ids      = [aws_security_group.webserver.id]
  subnet_id                   = sort(tolist(data.aws_subnet_ids.default.ids))[0]
  associate_public_ip_address = false
  user_data                   = local.user_data

  tags = {
    Name = "${var.alb_name}-webserver"
  }
}

resource "aws_lb_target_group" "webserver" {
  name     = "${var.alb_name}-webserver-tg"
  port     = local.default_http_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "webserver" {
  target_group_arn = aws_lb_target_group.webserver.arn
  target_id        = aws_instance.webserver.id
  port             = local.default_http_port
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn = module.alb.listener_arns[local.alb_entry_port]
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }

  condition {
    host_header {
      values = ["${var.alb_subdomain}.${var.base_domain_name}"]
    }
  }
}

resource "aws_security_group" "webserver" {
  vpc_id = data.aws_vpc.default.id

  # Inbound HTTP from ALB
  ingress {
    from_port       = local.default_http_port
    to_port         = local.default_http_port
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
  }

  tags = {
    Name = "${var.alb_name}-webserver"
  }
}
