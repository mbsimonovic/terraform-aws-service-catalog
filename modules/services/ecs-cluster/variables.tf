# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "cluster_min_size" {
  description = "The minimum number of instances to run in the ECS cluster"
  type        = number
}

variable "cluster_max_size" {
  description = "The maxiumum number of instances to run in the ECS cluster"
  type        = number
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the ECS cluster (e.g. t2.medium)"
  type        = string
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster. You can build the AMI using the Packer template ecs-node-al2.json. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required."
  type        = string
}

variable "cluster_instance_associate_public_ip_address" {
  description = "Whether to associate a public IP address with an instance in a VPC"
  type        = bool
  default     = false
}


variable "cluster_instance_ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with ECS workers. You can build the AMI using the Packer template ecs-node-al2.json. Only used if var.cluster_instance_ami is null. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required. Set to null if cluster_instance_ami is set."
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
  description = "The ID of the VPC in which the ECS cluster should be launched"
  type        = string
}

variable "vpc_subnet_ids" {
  description = "The IDs of the subnets in which to deploy the ECS cluster instances"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the ECS cluster instances during boot. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax"
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "public_alb_sg_ids" {
  description = "The Security Group ID for the public ALB"
  type        = list(string)
  default     = []
}

variable "internal_alb_sg_ids" {
  description = "The Security Group ID for the internal ALB"
  type        = list(string)
  default     = []
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
  type        = string
  default     = null
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to enable Cloudwatch log aggregation for the ECS cluster"
  type        = bool
  default     = true
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "allow_ssh_from_cidr_blocks" {
  description = "The IP address ranges in CIDR format from which to allow incoming SSH requests to the ECS instances."
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which to allow incoming SSH requests to the ECS instances."
  type        = list(string)
  default     = []
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true"
  type        = bool
  default     = true
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true"
  type        = bool
  default     = true
}

variable "capacity_provider_enabled" {
  description = "Enable a capacity provider to autoscale the EC2 ASG created for this ECS cluster."
  type        = bool
  default     = false
}

variable "multi_az_capacity_provider" {
  description = "Enable a multi-az capacity provider to autoscale the EC2 ASGs created for this ECS cluster, only if capacity_provider_enabled = true"
  type        = bool
  default     = false
}

variable "capacity_provider_target" {
  description = "Target cluster utilization for the ASG capacity provider; a number from 1 to 100. This number influences when scale out happens, and when instances should be scaled in. For example, a setting of 90 means that new instances will be provisioned when all instances are at 90% utilization, while instances that are only 10% utilized (CPU and Memory usage from tasks = 10%) will be scaled in."
  type        = number
  default     = null
}

variable "capacity_provider_max_scale_step" {
  description = "Maximum step adjustment size to the ASG's desired instance count. A number between 1 and 10000."
  type        = number
  default     = null
}

variable "capacity_provider_min_scale_step" {
  description = "Minimum step adjustment size to the ASG's desired instance count. A number between 1 and 10000."
  type        = number
  default     = null
}

variable "autoscaling_termination_protection" {
  description = "Protect EC2 instances running ECS tasks from being terminated due to scale in (spot instances do not support lifecycle modifications). Note that the behavior of termination protection differs between clusters with capacity providers and clusters without. When capacity providers is turned on and this flag is true, only instances that have 0 ECS tasks running will be scaled in, regardless of capacity_provider_target. If capacity providers is turned off and this flag is true, this will prevent ANY instances from being scaled in."
  type        = bool
  default     = false
}


# ---------------------------------------------------------------------------------------------------------------------
# SSH GRUNT VARIABLES
# These variables optionally enable and configure access via ssh-grunt. See: https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt for more info.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the nodes in this ECS cluster. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-users"
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the nodes in this ECS cluster with sudo permissions. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------------------------------------------------
# CLUSTER VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_cluster_access_ports" {
  description = "Specify a list of ECS Cluster ports which should be accessible from the security groups given in cluster_access_from_sgs"
  type        = list(any)
  default     = []
}

variable "cluster_access_from_sgs" {
  description = "Specify a list of Security Groups that will have access to the ECS cluster. Only used if var.enable_cluster_access_ports is set to true"
  type        = list(any)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH MONITORING VARIABLES
# These variables optionally configure Cloudwatch alarms to monitor resource usage in the ECS cluster and raise alerts when defined thresholds are exceeded
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_ecs_cloudwatch_alarms" {
  description = "Set to true to enable several basic Cloudwatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn"
  default     = true
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to enable Cloudwatch metrics collection for the ECS cluster"
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications"
  type        = list(string)
  default     = []
}

variable "high_cpu_utilization_evaluation_periods" {
  description = "The number of periods over which data is compared to the specified threshold"
  type        = number
  default     = 2
}

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a CPU utilization percentage above this threshold. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 90
}

variable "high_cpu_utilization_statistic" {
  description = "The statistic to apply to the alarm's high CPU metric. Either of the following is supported: SampleCount, Average, Sum, Minimum, Maximum"
  type        = string
  default     = "Average"
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 300
}

variable "high_memory_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a memory utilization percentage above this threshold. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 90
}

variable "high_memory_utilization_period" {
  description = "The period, in seconds, over which to measure the memory utilization percentage. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 300
}

variable "high_memory_utilization_evaluation_periods" {
  description = "The number of periods over which data is compared to the specified threshold"
  type        = number
  default     = 2
}

variable "high_memory_utilization_statistic" {
  description = "The statistic to apply to the alarm's high CPU metric. Either of the following is supported: SampleCount, Average, Sum, Minimum, Maximum"
  type        = string
  default     = "Average"
}

variable "high_disk_utilization_threshold" {
  description = "Trigger an alarm if the EC2 instances in the ECS Cluster have a disk utilization percentage above this threshold. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 90
}

variable "high_disk_utilization_period" {
  description = "The period, in seconds, over which to measure the disk utilization percentage. Only used if var.enable_ecs_cloudwatch_alarms is set to true"
  type        = number
  default     = 300
}

variable "default_user" {
  description = "The default OS user for the ECS worker AMI. For AWS Amazon Linux AMIs, which is what the Packer template in ecs-node-al2.json uses, the default OS user is 'ec2-user'."
  type        = string
  default     = "ec2-user"
}

variable "disallowed_availability_zones" {
  description = "A list of availability zones in the region that should be skipped when deploying ECS. You can use this to avoid availability zones that may not be able to provision the resources (e.g instance type does not exist). If empty, allows all availability zones."
  type        = list(string)
  default     = []
}

# CloudWatch Log Group settings (for log aggregation)

variable "should_create_cloudwatch_log_group" {
  description = "When true, precreate the CloudWatch Log Group to use for log aggregation from the EC2 instances. This is useful if you wish to customize the CloudWatch Log Group with various settings such as retention periods and KMS encryption. When false, the CloudWatch agent will automatically create a basic log group to use."
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "The name of the log group to create in CloudWatch. Defaults to `var.cluster_name-logs`."
  type        = string
  default     = ""
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
