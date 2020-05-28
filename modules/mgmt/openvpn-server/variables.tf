# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The AMI to run on the OpenVPN Server. This should be built from the Packer template under openvpn-server.json."
  type        = string
}

variable "allow_vpn_from_cidr_list" {
  description = "A list of IP address ranges in CIDR format from which VPN access will be permitted. Attempts to access the OpenVPN Server from all other IP addresses will be blocked."
  type        = list(string)
}

variable "backup_bucket_name" {
  description = "The name of the S3 bucket that will be used to backup PKI secrets. This is a required variable because bucket names must be globally unique across all AWS customers."
  type        = string
}

variable "ca_cert_fields" {
  description = "An object with fields for the country, state, locality, organization, organizational unit, and email address to use with the OpenVPN CA certificate."
  type = object({
    ca_country  = string
    ca_state    = string
    ca_locality = string
    ca_org      = string
    ca_org_unit = string
    ca_email    = string
  })
  # Example:
  # ca_cert_fields = {
  #   ca_country  = "US"
  #   ca_state    = "AZ"
  #   ca_locality = "Phoenix"
  #   ca_org      = "Gruntwork"
  #   ca_org_unit = "OpenVPN"
  #   ca_email    = "support@gruntwork.io"
  # }
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the OpenVPN server."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet in which to deploy the OpenVPN server. Must be a subnet in var.vpc_id."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the OpenVPN Server and the other resources created by these templates"
  type        = string
  default     = "vpn"
}

variable "instance_type" {
  description = "The type of instance to run for the OpenVPN Server"
  type        = string
  default     = "t3.micro"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance. Leave blank if you don't want to enable Key Pair auth."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of an existing KMS customer master key (CMK) that will be used to encrypt/decrypt backup files. If null, a key will be created with permissions assigned by the following variables: cmk_administrator_iam_arns, cmk_user_iam_arns, cmk_external_user_iam_arns, allow_manage_key_permissions."
  type        = string
  default     = null
}

variable "cmk_administrator_iam_arns" {
  description = "A list of IAM ARNs for users who should be given administrator access to this CMK (e.g. arn:aws:iam::<aws-account-id>:user/<iam-user-arn>). If this list is empty, and var.kms_key_arn is null, the ARN of the current user will be used."
  type        = list(string)
  default     = []
}

variable "cmk_user_iam_arns" {
  description = "A list of IAM ARNs for users who should be given permissions to use this CMK (e.g.  arn:aws:iam::<aws-account-id>:user/<iam-user-arn>). If this list is empty, and var.kms_key_arn is null, the ARN of the current user will be used."
  type        = list(string)
  default     = []
}

variable "cmk_external_user_iam_arns" {
  description = "A list of IAM ARNs for users from external AWS accounts who should be given permissions to use this CMK (e.g. arn:aws:iam::<aws-account-id>:root)."
  type        = list(string)
  default     = []
}

variable "allow_manage_key_permissions_with_iam" {
  description = "If true, both the CMK's Key Policy and IAM Policies (permissions) can be used to grant permissions on the CMK. If false, only the CMK's Key Policy can be used to grant permissions on the CMK. False is more secure (and generally preferred), but true is more flexible and convenient."
  type        = bool
  default     = false
}

variable "allow_ssh_from_cidr_list" {
  description = "The IP address ranges in CIDR format from which to allow incoming SSH requests to the OpenVPN server."
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which to allow incoming SSH requests to the OpenVPN server."
  type        = list(string)
  default     = []
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your OpenVPN server."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this OpenVPN server. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this OpenVPN server with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "vpn_route_cidr_blocks" {
  description = "A list of CIDR ranges to be routed over the VPN."
  type        = list(string)
  default     = []
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "request_queue_name" {
  description = "The name of the sqs queue that will be used to receive new certificate requests."
  type        = string
  default     = "queue"
}

variable "revocation_queue_name" {
  description = "The name of the sqs queue that will be used to receive certification revocation requests. Note that the queue name will be automatically prefixed with 'openvpn-requests-'."
  type        = string
  default     = "queue"
}

variable "vpn_subnet" {
  description = "The subnet IP and mask vpn clients will be assigned addresses from. For example, 172.16.1.0 255.255.255.0. This is a non-routed network that only exists between the VPN server and the client. Therefore, it should NOT overlap with VPC addressing, or the client won't be able to access any of the VPC IPs. In general, we recommend using internal, non-RFC 1918 IP addresses, such as 172.16.xx.yy."
  type        = string
  default     = "172.16.1.0 255.255.255.0"
}

variable "create_route53_entry" {
  description = "Set to true to add var.domain_name as a Route 53 DNS A record for the OpenVPN server"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name to use for the OpenVPN server. Only used if var.create_route53_entry is true."
  type        = string
  default     = null
}

variable "hosted_zone_tags" {
  description = "An optional set of tags you can pass in for matching purposes if you have multiple hosted zones with the same name. See: https://www.terraform.io/docs/providers/aws/d/route53_zone.html#argument-reference specifically tags for more information."
  type        = map(string)
  default     = {}
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications."
  type        = list(string)
  default     = []
}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = ""
}

variable "external_account_arns" {
  description = "The ARNs of external AWS accounts where your IAM users are defined. This module will create IAM roles that users in those accounts will be able to assume to get access to the request/revocation SQS queues."
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "When a terraform destroy is run, should the backup s3 bucket be destroyed even if it contains files. Should only be set to true for testing/development"
  type        = bool
  default     = false
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the OpenVPN server while it boots. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax."
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}
