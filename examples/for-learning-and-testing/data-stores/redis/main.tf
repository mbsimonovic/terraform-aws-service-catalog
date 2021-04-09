# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ELASTICACHE REDIS REPLICATION GROUP WITH CLOUDWATCH METRICS AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"
}


provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# AN EXAMPLE OF AN ELASTICACHE REPLICATION GROUP WITH REDIS
# ------------------------------------------------------------------------------

module "redis" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/redis?ref=v1.0.8"
  source = "../../../../modules/data-stores/redis"

  name          = local.cluster_name
  redis_version = "5.0.6"
  port          = 6379

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # Since this is just an example, we don't deploy any CloudWatch resources in order to make it faster to deploy, however in
  # production you'll probably want to enable this feature.
  enable_cloudwatch_alarms = false

  # Since this is just an example, we are using a small ElastiCache instance with only 10GB of storage, no standby, no replicas,
  # and no automatic backups. You'll want to tweak all of these settings for production usage.
  instance_type             = "cache.t3.micro"
  apply_immediately         = true
  replication_group_size    = 1
  enable_automatic_failover = false
  enable_multi_az           = false
  maintenance_window        = "sun:05:00-sun:09:00"
  snapshot_retention_limit  = 0
  snapshot_window           = ""
}

locals {
  cluster_name = "${var.name}-redis"
}