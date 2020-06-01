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
  description = "The AMI to run on the bastion host. This should be built from the Packer template under bastion-host.json."
  type        = string
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
  description = "Set to true to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
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
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this bastion host. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this bastion host. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Bastion host."
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
  description = "Set to true to create a DNS record in Route53 pointing to the bastion. If true, be sure to set var.hosted_zone_id and var.domain_name."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The fully qualified host and domain name to use for the bastion server (e.g. bastion.foo.com). Only used if create_dns_record is true."
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
