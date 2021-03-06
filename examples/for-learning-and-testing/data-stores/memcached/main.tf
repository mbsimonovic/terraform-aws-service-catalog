# ------------------------------------------------------------------------------
# DEPLOY AN ELASTICACHE MEMCACHED CLUSTER WITH CLOUDWATCH METRICS AND ALERTS
# ------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}


provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# AN EXAMPLE OF AN ELASTICACHE MEMCACHED CLUSTER
# ------------------------------------------------------------------------------

module "memcached" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/memcached?ref=v1.0.8"
  source = "../../../../modules/data-stores/memcached"

  name              = local.cluster_name
  memcached_version = "1.5.16"
  port              = 11211

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # Since this is just an example, we don't deploy any CloudWatch resources in order to make it faster to deploy, however in
  # production you'll probably want to enable this feature.
  enable_cloudwatch_alarms = false

  # Since this is just an example, we are using a small ElastiCache cluster with only one node. You'll want to tweak
  # all of these settings for production usage.
  instance_type      = "cache.t3.micro"
  apply_immediately  = true
  num_cache_nodes    = 1
  az_mode            = "single-az"
  maintenance_window = "sun:05:00-sun:09:00"
}

locals {
  cluster_name = "${var.name}-memcached"
}