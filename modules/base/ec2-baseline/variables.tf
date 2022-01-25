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
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "The name of an IAM role to use for the various IAM policies created in this module, including ssh-grunt permissions, CloudWatch Metrics, and CloudWatch Logs. This variable is required if any of the following variables are true: enable_ssh_grunt, enable_cloudwatch_metrics, enable_cloudwatch_log_aggregation."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent to get memory and disk metrics in CloudWatch for your host."
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

variable "asg_names" {
  description = "The list of names of the autoscaling group to use when setting up CloudWatch alarms. Required if enable_asg_cloudwatch_alarms is true."
  type        = list(string)
  default     = []
}

variable "num_asg_names" {
  description = "The number of names in var.asg_names. We should be able to compute this automatically, but can't due to a Terraform limitation (https://github.com/hashicorp/terraform/issues/4149)."
  type        = number
  default     = 0
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications. Required if enable_cloudwatch_alarms is true."
  type        = list(string)
  default     = []
}

variable "should_render_cloud_init" {
  description = "If true, combine the parts in var.cloud_init_parts using a cloudinit_config data source and provide the rendered result as an output. If false, no output will be rendered. If true, cloud_init_parts is required. Defaults to true."
  type        = bool
  default     = true
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the host while it boots. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax."
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "ami" {
  description = "The ID of an AMI to use for deploying servers. This provides a convenience function for choosing between looking up an AMI with filters, or returning a hard coded AMI ID. Only used if var.ami_filters is null."
  type        = string
  default     = null
}

variable "ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI. Define one of var.ami_filters and var.ami. If both are defined, var.ami_filters is used."
  type = object({
    # List of owners to limit the search. Set to null if you do not wish to limit the search by AMI owners.
    owners = list(string)

    # Name/Value pairs to filter the AMI off of. There are several valid keys, for a full reference, check out the
    # documentation for describe-images in the AWS CLI reference
    # (https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html).
    filters = list(object({
      name   = string
      values = list(string)
    }))
  })
  default = null
}

variable "should_create_cloudwatch_log_group" {
  description = "When true, precreate the CloudWatch Log Group to use for log aggregation from the EC2 instances. This is useful if you wish to customize the CloudWatch Log Group with various settings such as retention periods and KMS encryption. When false, the CloudWatch agent will automatically create a basic log group to use."
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group to use for log aggregation. This should match the configuration in the user data script call. Only used if var.enable_cloudwatch_log_aggregation and var.should_create_cloudwatch_log_group is true."
  type        = string
  default     = null
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "The number of days to retain log events in the log group. Refer to https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group#retention_in_days for all the valid values. When null, the log events are retained forever."
  type        = number
  default     = null
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ID (ARN, alias ARN, AWS ID) of a customer managed KMS Key to use for encrypting log data."
  type        = string
  default     = null
}

variable "cloudwatch_log_group_tags" {
  description = "Tags to apply on the CloudWatch Log Group, encoded as a map where the keys are tag keys and values are tag values."
  type        = map(string)
  default     = null
}
