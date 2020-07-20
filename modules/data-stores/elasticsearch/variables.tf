# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

# Cluster configuration

variable "domain_name" {
  description = "The name of the Elasticsearch cluster. It must be unique to your account and region, start with a lowercase letter, contain between 3 and 28 characters, and contain only lowercase letters a-z, the numbers 0-9, and the hyphen (-)."
  type        = string
}

variable "instance_type" {
  description = "The instance type to use for Elasticsearch data nodes (e.g., t2.small.elasticsearch, or m4.large.elasticsearch). For supported instance types see https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-supported-instance-types.html."
  type        = string
}

variable "instance_count" {
  description = "The number of instances to deploy in the Elasticsearch cluster. This must be an even number if zone_awareness_enabled is true."
  type        = number
}

variable "volume_type" {
  description = "The type of EBS volumes to use in the cluster. Must be one of: standard, gp2, io1, sc1, or st1. For a comparison of EBS volume types, see https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ebs-volume-types.html."
  type        = string
}

variable "volume_size" {
  description = "The size in GiB of the EBS volume for each node in the cluster (e.g. 10, or 512). For volume size limits see https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-limits.html."
  type        = number
}

variable "zone_awareness_enabled" {
  description = "Whether to deploy the Elasticsearch nodes across two Availability Zones instead of one. Note that if you enable this, the instance_count MUST be an even number."
  type        = bool
}

# Network configuration

variable "vpc_id" {
  description = "The id of the VPC to deploy into. It must be in the same region as the Elasticsearch domain and its tenancy must be set to Default. If zone_awareness_enabled is false, the Elasticsearch cluster will have an endpoint in one subnet of the VPC; otherwise it will have endpoints in two subnets."
  type        = string
}

variable "subnet_ids" {
  description = "VPC Subnet IDs for the Elasticsearch domain endpoints to be created in. If zone_awareness_enabled is true, the first two provided subnet ids are used; otherwise only the first one is used."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "elasticsearch_version" {
  description = "The version of Elasticsearch to deploy."
  type        = string
  default     = "7.4"
}

variable "dedicated_master_enabled" {
  description = "Whether to deploy separate nodes specifically for performing cluster management tasks (e.g. tracking number of nodes, monitoring health, replicating changes). This increases the stability of large clusters and is required for clusters with more than 10 nodes."
  type        = bool
  default     = false
}

variable "dedicated_master_type" {
  description = "The instance type for the dedicated master nodes. These nodes can use a different instance type than the rest of the cluster. Only used if var.dedicated_master_enabled is true."
  type        = string
  default     = null
}

variable "dedicated_master_count" {
  description = "The number of dedicated master nodes to run. We recommend setting this to 3 for production deployments. Only used if var.dedicated_master_enabled is true."
  type        = number
  default     = null
}

variable "iops" {
  description = "The baseline input/output (I/O) performance of EBS volumes attached to data nodes. Must be between 1000 and 4000. Applicable only if var.volume_type is io1."
  type        = number
  default     = null
}

variable "allow_connections_from_cidr_blocks" {
  description = "The list of network CIDR blocks to allow network access to Aurora from. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = set(string)
  default     = []
}

variable "allow_connections_from_security_groups" {
  description = "The list of IDs or Security Groups to allow network access to Aurora from. All security groups must either be in the VPC specified by var.vpc_id, or a peered VPC with the VPC specified by var.vpc_id. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = set(string)
  default     = []
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

variable "alarm_sns_topic_arns" {
  description = "ARNs of the SNS topics associated with the CloudWatch alarms for the Elasticsearch cluster."
  type        = list(string)
  default     = []
}
