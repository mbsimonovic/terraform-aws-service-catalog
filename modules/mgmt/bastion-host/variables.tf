# ------------------- -------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the bastion."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet in which to deploy the bastion. Must be a subnet in var.vpc_id."
  type        = string
}

variable "ami" {
  description = "The AMI to run on the bastion host. This should be built from the Packer template under bastion-host.json. One of var.ami or var.ami_filters is required. Set to null if looking up the ami with filters."
  type        = string
}

variable "ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with the Bastion Host. You can build the AMI using the Packer template bastion-host.json. Only used if var.ami is null. One of var.ami or var.ami_filters is required. Set to null if passing the ami ID directly."
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

variable "allow_ssh_from_cidr_list" {
  description = "A list of IP address ranges in CIDR format from which SSH access will be permitted. Attempts to access the bastion host from all other IP addresses will be blocked. This is only used if var.allow_ssh_from_cidr is true."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the bastion host and the other resources created by these templates"
  type        = string
  default     = "bastion-host"
}

variable "instance_type" {
  description = "The type of instance to run for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance."
  type        = string
  default     = null
}

variable "external_account_ssh_grunt_role_arn" {
  description = "If you are using ssh-grunt and your IAM users / groups are defined in a separate AWS account, you can use this variable to specify the ARN of an IAM role that ssh-grunt can assume to retrieve IAM group and public SSH key info from that account. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true."
  type        = bool
  default     = true
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true."
  type        = bool
  default     = true
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this Bastion Host. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-users"
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this Bastion Host with sudo permissions. This value is only used if enable_ssh_grunt=true."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent to get memory and disk metrics in CloudWatch for your Bastion host."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications."
  type        = list(string)
  default     = []
}

variable "create_dns_record" {
  description = "Set to true to create a DNS record in Route53 pointing to the bastion. If true, be sure to set var.domain_name."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The apex domain of the hostname for the bastion server (e.g., example.com). The complete hostname for the bastion server will be var.name.var.domain_name (e.g., bastion.example.com). Only used if create_dns_record is true."
  type        = string
  default     = ""
}

variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)"
  type        = map(string)
  default     = {}
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

variable "default_user" {
  description = "The default OS user for the Bastion Host AMI. For AWS Ubuntu AMIs, which is what the Packer template in bastion-host.json uses, the default OS user is 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "additional_security_group_ids" {
  description = "A list of optional additional security group ids to assign to the bastion server."
  type        = list(string)
  default     = []
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
