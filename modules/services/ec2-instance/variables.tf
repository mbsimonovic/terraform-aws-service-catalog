# ------------------- -------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the EC2 instance."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet in which to deploy the EC2 instance. Must be a subnet in var.vpc_id."
  type        = string
}

variable "ami" {
  description = "The AMI to run on the EC2 instance. This should be built from the Packer template under ec2-instance.json. One of var.ami or var.ami_filters is required. Set to null if looking up the ami with filters."
  type        = string
}

variable "ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with the EC2 instance. You can build the AMI using the Packer template ec2-instance.json. Only used if var.ami is null. One of var.ami or var.ami_filters is required. Set to null if passing the ami ID directly."
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the EC2 instance and the other resources created by these templates"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to run for the EC2 instance"
  type        = string
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance. This instance may have ssh-grunt installed. The preferred way to do SSH access is with your own IAM user name and SSH key. This Key Pair is only as a fallback."
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
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this EC2 instance. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to this EC2 instance. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "tenancy" {
  description = "The tenancy of this instance. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your EC2 instance."
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
  description = "Set to true to create a DNS record in Route53 pointing to the EC2 instance. If true, be sure to set var.fully_qualified_domain_name."
  type        = bool
  default     = true
}

variable "dns_ttl" {
  description = "DNS Time To Live in seconds."
  type        = number
  default     = 300
}

variable "fully_qualified_domain_name" {
  description = "The apex domain of the hostname for the EC2 instance (e.g., example.com). The complete hostname for the EC2 instance will be var.name.var.fully_qualified_domain_name (e.g., bastion.example.com). Only used if create_dns_record is true."
  type        = string
  default     = ""
}

variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)"
  type        = map(string)
  default     = {}
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the EC2 instance while it boots. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax."
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "default_user" {
  description = "The default OS user for the EC2 instance AMI. For AWS Ubuntu AMIs, which is what the Packer template in ec2-instance.json uses, the default OS user is 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "ebs_volumes" {
  description = "The EBS volumes to attach to the instance. This must be a map of key/value pairs."
  type        = any
  # The value of the secret must be a map:
  # {
  #   "demo-volume" = {
  #     type        = "gp2"
  #     size        = 5
  #     device_name = "/dev/xvdf"
  #     mount_point = "/mnt/demo"
  #     region      = "us-east-1"
  #     owner       = "ubuntu"
  #   },
  # }
  #
  # Other keys include "encrypted", "iops", "snapshot_id", "kms_key_id", "throughput", and "tags". See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume for more information. 
}

variable "allow_port_from_cidr_blocks" {
  description = "Accept inbound traffic on these port ranges from the specified CIDR blocks"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "allow_port_from_security_group_ids" {
  description = "Accept inbound traffic on these port ranges from the specified security groups"
  type = map(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    source_security_group_id = string
  }))
}

variable "allow_ssh_from_cidr_blocks" {
  description = "Accept inbound SSH from these CIDR blocks"
  type        = list(string)
}

variable "allow_ssh_from_security_group_ids" {
  description = "Accept inbound SSH from these security groups"
  type        = list(string)
}

variable "dns_zone_is_private" {
  description = "Specify whether we're selecting a private or public Route 53 DNS Zone"
  type        = bool
}

variable "tags" {
  description = "A map of tags to apply to the EC2 instance and the S3 Buckets. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "route53_zone_id" {
  description = "The ID of the hosted zone to use. Allows specifying the hosted zone directly instead of looking it up via domain name. Only one of route53_lookup_domain_name or route53_zone_id should be used."
  type        = string
}

variable "route53_lookup_domain_name" {
  description = "The domain name to use to look up the Route 53 hosted zone. Will be a subset of fully_qualified_domain_name: e.g., my-company.com. Only one of route53_lookup_domain_name or route53_zone_id should be used."
}

variable "root_volume_type" {
  description = "The root volume type. Must be one of: standard, gp2, io1."
  type        = string
  default     = "standard"
}

variable "root_volume_size" {
  description = "The size of the root volume, in gigabytes."
  type        = number
  default     = 8
}

variable "root_volume_delete_on_termination" {
  description = "If set to true, the root volume will be deleted when the Instance is terminated."
  type        = bool
  default     = true
}

variable "additional_security_group_ids" {
  description = "A list of optional additional security group ids to assign to the bastion server."
  type        = list(string)
  default     = []
}
