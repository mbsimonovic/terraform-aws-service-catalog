# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this example terraform module.
# ---------------------------------------------------------------------------------------------------------------------

variable "domain_name" {
  description = "The name of the Elasticsearch cluster. It must be unique to your account and region, start with a lowercase letter, contain between 3 and 28 characters, and contain only lowercase letters a-z, the numbers 0-9, and the hyphen (-)."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables are set with defaults to make running the example easier.
# ---------------------------------------------------------------------------------------------------------------------

variable "is_public" {
  description = "Whether the cluster is accessible publicly."
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created."
  type        = string
  default     = "eu-west-1"
}

variable "elasticsearch_version" {
  description = "The version of Elasticsearch to deploy (e.g., 7.7)."
  type        = string
  default     = "7.7"
}

variable "instance_type" {
  description = "The instance type to use for Elasticsearch data nodes (e.g., t2.small.elasticsearch, or m4.large.elasticsearch). For supported instance types see https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-supported-instance-types.html."
  type        = string
  default     = "t2.small.elasticsearch"
}

variable "instance_count" {
  description = "The number of instances to deploy in the Elasticsearch cluster."
  type        = number
  default     = 1
}

variable "zone_awareness_enabled" {
  description = "Whether to deploy the Elasticsearch nodes across two Availability Zones instead of one. Note that if you enable this, the instance_count MUST be an even number."
  type        = bool
  default     = false
}

variable "volume_type" {
  description = "The type of EBS volumes to use in the cluster. Must be one of: standard, gp2, io1, sc1, or st1. For a comparison of EBS volume types, see https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ebs-volume-types.html."
  type        = string
  default     = "gp2"
}

variable "volume_size" {
  description = "The size in GiB of the EBS volume for each node in the cluster (e.g. 10, or 512). For volume size limits see https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-limits.html."
  type        = number
  default     = 10
}

variable "automated_snapshot_start_hour" {
  description = "Hour during which the service takes an automated daily snapshot of the indices in the domain. This setting has no effect on Elasticsearch 5.3 and later."
  type        = number
  default     = 0
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arns."
  type        = bool
  default     = true
}
