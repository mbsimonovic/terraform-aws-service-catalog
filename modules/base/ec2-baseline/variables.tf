# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERs
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "A name to apply to the resources created by this template."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed, or may only be required under certain conditions.
# ---------------------------------------------------------------------------------------------------------------------

variable "external_account_ssh_grunt_role_arn" {
  description = "If you are using ssh-grunt and your IAM users / groups are defined in a separate AWS account, you can use this variable to specify the ARN of an IAM role that ssh-grunt can assume to retrieve IAM group and public SSH key info from that account. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "iam_role_arn" {
  description = "The ARN of an IAM role to use for the various IAM policies created in this module, including ssh-grunt permissions, CloudWatch Metrics, and CloudWatch Logs. This variable is required if any of the following variables are true: enable_ssh_grunt, enable_cloudwatch_metrics, enable_cloudwatch_log_aggregation."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Bastion host."
  type        = bool
  default     = true
}

variable "enable_instance_cloudwatch_alarms" {
  description = "Set to true to enable basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. Use this for an instance, and use enable_asg_cloudwatch_alarms for an ASG. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = false
}

variable "enable_asg_cloudwatch_alarms" {
  description = "Set to true to enable basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. Use this for an autoscaling group, and use enable_asg_cloudwatch_alarms for an instance. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = false
}

variable "instance_id" {
  description = "The ID of the instance to use when setting up CloudWatch alarms. Required if enable_instance_cloudwatch_alarms is true."
  type        = string
  default     = ""
}

variable "asg_name" {
  description = "The name of the autoscaling group to use when setting up CloudWatch alarms. Required if enable_asg_cloudwatch_alarms is true."
  type        = string
  default     = ""
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications. Required if enable_cloudwatch_alarms is true."
  type        = list(string)
  default     = []
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the bastion host while it boots. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax."
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}
