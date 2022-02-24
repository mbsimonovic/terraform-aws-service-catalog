# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "instance_type" {
  description = "The instance type to use for the Jenkins server (e.g. t2.medium)"
  type        = string
}

variable "ami" {
  description = "The ID of the AMI to run on the Jenkins server. This should be the AMI build from the Packer template jenkins-ubuntu.json. One of var.ami or var.ami_filters is required. Set to null if looking up the ami with filters."
  type        = string
}

variable "ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with Jenkins. You can build the AMI using the Packer template jenkins-ubuntu.json. Only used if var.ami is null. One of var.ami or var.ami_filters is required. Set to null if passing the ami ID directly."
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
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy Jenkins"
  type        = string
}

variable "jenkins_subnet_id" {
  description = "The ID of the subnet in which to deploy Jenkins. Must be a subnet in var.vpc_id."
  type        = string
}

variable "alb_subnet_ids" {
  description = "The IDs of the subnets in which to deploy the ALB that runs in front of Jenkins. Must be subnets in var.vpc_id."
  type        = list(string)
}

variable "memory" {
  description = "The amount of memory to give Jenkins (e.g., 1g or 512m). Used for the -Xms and -Xmx settings."
  type        = string
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for Jenkins."
  type        = string
}

variable "domain_name" {
  description = "The domain name for the DNS A record to add for Jenkins (e.g. jenkins.foo.com). Must be in the domain managed by var.hosted_zone_id."
  type        = string
}

variable "acm_ssl_certificate_domain" {
  description = "The domain name used for an SSL certificate issued by the Amazon Certificate Manager (ACM)."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Enter the name of the Jenkins server"
  type        = string
  default     = "jenkins"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the Jenkins server. Leave blank if you don't want to enable Key Pair auth."
  type        = string
  default     = null
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "jenkins_volume_encrypted" {
  description = "Set to true to encrypt the Jenkins EBS volume."
  type        = bool
  default     = true
}

variable "ebs_kms_key_arn" {
  description = "The ARN of the KMS key used for encrypting the Jenkins EBS volume. The module will grant Jenkins permission to use this key."
  type        = string
  default     = null
}

variable "ebs_kms_key_arn_is_alias" {
  description = "Whether or not the provide EBS KMS key ARN is a key alias. If providing the key ID, leave this set to false."
  type        = bool
  default     = false
}

variable "jenkins_device_name" {
  description = "The OS device name where the Jenkins EBS volume should be attached"
  type        = string
  default     = "/dev/xvdh"
}

variable "jenkins_mount_point" {
  description = "The OS path where the Jenkins EBS volume should be mounted"
  type        = string
  default     = "/jenkins"
}

variable "jenkins_user" {
  description = "The OS user that should be used to run Jenkins"
  type        = string
  default     = "jenkins"
}

variable "backup_using_lambda" {
  description = "Set to true to backup the Jenkins Server using a Scheduled Lambda Function."
  type        = bool
  default     = false
}

variable "backup_job_metric_namespace" {
  description = "The namespace for the CloudWatch Metric the AWS lambda backup job will increment every time the job completes successfully."
  type        = string
  default     = "Custom/Jenkins"
}

variable "backup_job_metric_name" {
  description = "The name for the CloudWatch Metric the AWS lambda backup job will increment every time the job completes successfully."
  type        = string
  default     = "jenkins-backup-job"
}

variable "backup_job_schedule_expression" {
  description = "A cron or rate expression that specifies how often to take a snapshot of the Jenkins server for backup purposes. See https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html for syntax details."
  type        = string
  default     = "rate(1 day)"
}

variable "backup_job_alarm_period" {
  description = "How often, in seconds, the backup job is expected to run. This is the same as var.backup_job_schedule_expression, but unfortunately, Terraform offers no way to convert rate expressions to seconds. We add a CloudWatch alarm that triggers if the value of var.backup_job_metric_name and var.backup_job_metric_namespace isn't updated within this time period, as that indicates the backup failed to run."
  type        = number

  # One day in seconds
  default = 86400
}

variable "backup_using_dlm" {
  description = "Set to true to backup the Jenkins Server using AWS Data Lifecycle Management Policies."
  type        = bool
  default     = true
}

variable "dlm_backup_job_schedule_name" {
  description = "The name of the data lifecyle management schedule"
  type        = string
  default     = "daily-last-two-weeks"
}

variable "dlm_backup_job_schedule_interval" {
  description = "How often this lifecycle policy should be evaluated, in hours."
  type        = number
  default     = 24
}

variable "dlm_backup_job_schedule_times" {
  description = "A list of times in 24 hour clock format that sets when the lifecyle policy should be evaluated. Max of 1."
  type        = list(string)
  default     = ["03:00"]
}

variable "dlm_backup_job_schedule_number_of_snapshots_to_retain" {
  type        = number
  description = "How many snapshots to keep. Must be an integer between 1 and 1000."
  default     = 15
}

variable "skip_health_check" {
  description = "If set to true, skip the health check, and start a rolling deployment of Jenkins without waiting for it to initially be in a healthy state. This is primarily useful if the server group is in a broken state and you want to force a deployment anyway."
  type        = bool
  default     = false
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the Jenkins server when it is booting. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax."
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "is_internal_alb" {
  description = "Set to true to make the Jenkins ALB an internal ALB that cannot be accessed from the public Internet. We strongly recommend setting this to true to keep Jenkins more secure."
  type        = bool
  default     = true
}

variable "allow_incoming_http_from_cidr_blocks" {
  description = "The IP address ranges in CIDR format from which to allow incoming HTTP requests to Jenkins."
  type        = list(string)
  default     = []
}

variable "allow_incoming_http_from_security_group_ids" {
  description = "The IDs of security groups from which to allow incoming HTTP requests to Jenkins."
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_cidr_blocks" {
  description = "The IP address ranges in CIDR format from which to allow incoming SSH requests to Jenkins."
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which to allow incoming SSH requests to Jenkins."
  type        = list(string)
  default     = []
}

variable "root_block_device_volume_type" {
  description = "The type of volume to use for the root disk for Jenkins. Must be one of: standard, gp2, io1, sc1, or st1."
  type        = string
  default     = "gp2"
}

variable "root_volume_size" {
  description = "The amount of disk space, in GB, to allocate for the root volume of this server. Note that all of Jenkins' data is stored on a separate EBS Volume (see var.jenkins_volume_size), so this root volume is primarily used for the OS, temp folders, apps, etc."
  type        = number
  default     = 100
}

variable "jenkins_volume_type" {
  description = "The type of volume to use for the EBS volume used by the Jenkins server. Must be one of: standard, gp2, io1, sc1, or st1."
  type        = string
  default     = "gp2"
}

variable "jenkins_volume_size" {
  description = "The amount of disk space, in GB, to allocate for the EBS volume used by the Jenkins server."
  type        = number
  default     = 200
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this Jenkins server. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-users"
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this Jenkins server with sudo permissions. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "external_account_ssh_grunt_role_arn" {
  description = "If you are using ssh-grunt and your IAM users / groups are defined in a separate AWS account, you can use this variable to specify the ARN of an IAM role that ssh-grunt can assume to retrieve IAM group and public SSH key info from that account. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent to get memory and disk metrics in CloudWatch for your Jenkins server."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications. Also used for the alarms if the Jenkins backup job fails."
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to add AIM permissions to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "build_permission_actions" {
  description = "The list of IAM actions this Jenkins server should be allowed to do: e.g., ec2:*, s3:*, etc. This should be the list of IAM permissions Jenkins needs in this AWS account to run builds. These permissions will be added to the server's IAM role for all resources ('*')."
  type        = list(string)
  default     = []
}

variable "external_account_auto_deploy_iam_role_arns" {
  description = "A list of IAM role ARNs in other AWS accounts that Jenkins will be able to assume to do automated deployment in those accounts."
  type        = list(string)
  default     = []
}

variable "default_user" {
  description = "The default OS user for the Jenkins AMI. For AWS Ubuntu AMIs, which is what the Packer template in jenkins-ubunutu.json uses, the default OS user is 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "custom_tags" {
  description = "A list of custom tags to apply to Jenkins and all other resources."
  type        = map(string)
  default     = {}
}

# CloudWatch Log Group settings (for log aggregation)

variable "should_create_cloudwatch_log_group" {
  description = "When true, precreate the CloudWatch Log Group to use for log aggregation from the EC2 instances. This is useful if you wish to customize the CloudWatch Log Group with various settings such as retention periods and KMS encryption. When false, the CloudWatch agent will automatically create a basic log group to use."
  type        = bool
  default     = true
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

# ---------------------------------------------------------------------------------------------------------------------
# BACKWARD COMPATIBILITY FEATURE FLAGS
# The following variables are feature flags to enable and disable certain features in the module. These are primarily
# introduced to maintain backward compatibility by avoiding unnecessary resource creation.
# ---------------------------------------------------------------------------------------------------------------------

variable "use_managed_iam_policies" {
  description = "When true, all IAM policies will be managed as dedicated policies rather than inline policies attached to the IAM roles. Dedicated managed policies are friendlier to automated policy checkers, which may scan a single resource for findings. As such, it is important to avoid inline policies when targeting compliance with various security standards."
  type        = bool
  default     = true
}

locals {
  use_inline_policies = var.use_managed_iam_policies == false
}
