# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN APPLICATION LOAD BALANCER (ALB)
# A single ALB can be shared among multiple ECS Clusters, ECS Services or Auto Scaling Groups. For this reason, it's
# created separately from those resources.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that may have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB
# ---------------------------------------------------------------------------------------------------------------------

module "alb" {
  source = "git::git@github.com:gruntwork-io/module-load-balancer.git//modules/alb?ref=v0.21.0"

  # You can find the list of policies here: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
  ssl_policy = "ELBSecurityPolicy-2016-08"

  alb_name        = var.alb_name
  is_internal_alb = var.is_internal_alb

  http_listener_ports = var.http_listener_ports

  https_listener_ports_and_ssl_certs     = var.https_listener_ports_and_ssl_certs
  https_listener_ports_and_ssl_certs_num = length(var.https_listener_ports_and_ssl_certs)

  https_listener_ports_and_acm_ssl_certs     = var.https_listener_ports_and_acm_ssl_certs
  https_listener_ports_and_acm_ssl_certs_num = length(var.https_listener_ports_and_acm_ssl_certs)

  allow_inbound_from_cidr_blocks = var.allow_inbound_from_cidr_blocks

  allow_inbound_from_security_group_ids     = var.allow_inbound_from_security_group_ids
  allow_inbound_from_security_group_ids_num = length(var.allow_inbound_from_security_group_ids)

  vpc_id = var.vpc_id
  #TODO: Add an assertion script to ensure that user doesn't pass in a private subnet for public ALB and vice versa
  vpc_subnet_ids = var.vpc_subnet_ids

  enable_alb_access_logs         = true
  alb_access_logs_s3_bucket_name = var.should_create_access_logs_bucket ? module.alb_access_logs_bucket.s3_bucket_name : var.access_logs_s3_bucket_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET USED TO STORE THE ALB'S LOGS
# ---------------------------------------------------------------------------------------------------------------------

# Create an S3 Bucket to store ALB access logs.
module "alb_access_logs_bucket" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/logs/load-balancer-access-logs?ref=v0.23.1"

  # Try to do some basic cleanup to get a valid S3 bucket name: the name must be lower case and can only contain
  # lowercase letters, numbers, and hyphens. For the full rules, see:
  # http://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules
  s3_bucket_name = (
    var.access_logs_s3_bucket_name != null
    ? var.access_logs_s3_bucket_name
    : "alb-${lower(replace(var.alb_name, "_", "-"))}-access-logs"
  )
  s3_logging_prefix = var.alb_name

  num_days_after_which_archive_log_data = var.num_days_after_which_archive_log_data
  num_days_after_which_delete_log_data  = var.num_days_after_which_delete_log_data

  force_destroy = var.force_destroy
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A DNS RECORD USING ROUTE 53
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "dns_record" {
  count = var.create_route53_entry ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_hosted_zone_id
    evaluate_target_health = true
  }
}
