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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# Network configuration

variable "is_public" {
  description = "Whether the cluster is publicly accessible."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "The id of the VPC to deploy into. It must be in the same region as the Elasticsearch domain and its tenancy must be set to Default. If zone_awareness_enabled is false, the Elasticsearch cluster will have an endpoint in one subnet of the VPC; otherwise it will have endpoints in two subnets."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = " List of VPC Subnet IDs for the Elasticsearch domain endpoints to be created in. If var.zone_awareness_enabled is true, the first 2 or 3 provided subnet ids are used, depending on var.availability_zone_count. Otherwise only the first one is used."
  type        = list(string)
  default     = []
}

variable "availability_zone_count" {
  description = "Number of Availability Zones for the domain to use with var.zone_awareness_enabled. Defaults to 2. Valid values: 2 or 3."
  type        = number
  default     = 2
}

# Cluster configuration

variable "elasticsearch_version" {
  description = "The version of Elasticsearch to deploy."
  type        = string
  default     = "7.7"
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

variable "custom_tags" {
  description = "A map of custom tags to apply to the ElasticSearch Domain. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
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

variable "iam_principal_arns" {
  description = "The ARNS of the IAM users and roles to which to allow full access to the Elasticsearch cluster. Setting this to a restricted list is useful when using a public access cluster."
  type        = list(string)
  default     = ["*"]
}

variable "advanced_options" {
  description = "Key-value string pairs to specify advanced configuration options. Note that the values for these configuration options must be strings (wrapped in quotes)."
  type        = map(any)
  default     = {}
}

variable "enable_node_to_node_encryption" {
  description = "Whether to enable node-to-node encryption. "
  type        = bool
  default     = true
}

variable "tls_security_policy" {
  description = "The name of the TLS security policy that needs to be applied to the HTTPS endpoint. Valid values are Policy-Min-TLS-1-0-2019-07 and Policy-Min-TLS-1-2-2019-07. Terraform performs drift detection if this is configured."
  type        = string
  default     = "Policy-Min-TLS-1-2-2019-07"
}

variable "custom_endpoint_enabled" {
  description = "Whether to enable custom endpoint for the Elasticsearch domain."
  type        = bool
  default     = false
}

variable "custom_endpoint" {
  description = "Fully qualified domain for your custom endpoint."
  type        = string
  default     = null
}

variable "custom_endpoint_certificate_arn" {
  description = "ACM certificate ARN for your custom endpoint."
  type        = string
  default     = null
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

variable "update_timeout" {
  description = "How long to wait for updates to the ES cluster before timing out and reporting an error."
  type        = string
  # The default for the aws_elasticsearch_domain resource is 60m, but we've seen that timeout on creation, so just in
  # case, we set 90m to try to reduce spurious errors.
  default = "90m"
}

variable "enable_encryption_at_rest" {
  description = "False by default because encryption at rest is not included in the free tier. When true, the Elasticsearch domain storage will be encrypted at rest using the KMS key described with var.encryption_kms_key_id. We strongly recommend configuring a custom KMS key instead of using the shared service key for a better security posture when configuring encryption at rest."
  type        = bool
  default     = true
}

variable "encryption_kms_key_id" {
  description = "The ID of the KMS key to use to encrypt the Elasticsearch domain storage. Only used if enable_encryption_at_rest. When null, uses the aws/es service KMS key."
  type        = string
  default     = null
}

variable "create_service_linked_role" {
  description = "Whether or not the Service Linked Role for Elasticsearch should be created within this module. Normally the service linked role is created automatically by AWS when creating the Elasticsearch domain in the web console, but API does not implement this logic. You can either have AWS automatically manage this by creating a domain manually in the console, or manage it in terraform using the landing zone modules or this variable."
  type        = bool
  default     = false
}

variable "ebs_enabled" {
  description = "Set to false to disable EBS volumes. This is useful for nodes that have optimized instance storage, like hosts running the i3 instance type."
  type        = bool
  default     = true
}

variable "advanced_security_options" {
  description = "Enable fine grain access control"
  type        = bool
  default     = false
}

variable "internal_user_database_enabled" {
  description = "Whether the internal user database is enabled. Enable this to use master accounts. Only used if advanced_security_options is set to true."
  type        = bool
  default     = false
}

variable "master_user_arn" {
  description = "ARN of the master user. Only used if advanced_security_options and internal_user_database_enabled are set to true."
  type        = string
  default     = null
}

variable "master_user_name" {
  description = "Master account user name. Only used if advanced_security_options and internal_user_database_enabled are set to true."
  type        = string
  default     = null
}

variable "master_user_password" {
  description = "Master account user password. Only used if advanced_security_options and internal_user_database_enabled are set to true. WARNING: this password will be stored in Terraform state."
  type        = string
  default     = null
  sensitive   = true
}
