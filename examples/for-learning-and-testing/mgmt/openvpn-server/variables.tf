# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_version_tag" {
  description = "The version string of the AMI to run for the OpenVPN server built from the template in modules/mgmt/openvpn-server/openvpn-server.json. This corresponds to the value passed in for version_tag in the Packer template."
  type        = string
}

variable "backup_bucket_name" {
  description = "The name of the S3 bucket that will be used to backup PKI secrets. This is a required variable because bucket names must be globally unique across all AWS customers."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

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
  description = "A list of IAM ARNs for users who should be given permissions to use this KMS Master Key (e.g. arn:aws:iam::1234567890:user/foo)."
  type = list(object({
    name = list(string)
    conditions = list(object({
      test     = string
      variable = string
      values   = list(string)
    }))
  }))
  default = []
}


variable "cmk_external_user_iam_arns" {
  description = "A list of IAM ARNs for users from external AWS accounts who should be given permissions to use this CMK (e.g. arn:aws:iam::<aws-account-id>:root)."
  type        = list(string)
  default     = []
}

variable "name" {
  description = "The name of the OpenVPN server."
  type        = string
  default     = "openvpn-server"
}

variable "additional_vpn_route_cidr_blocks" {
  description = "A list of CIDR ranges to be routed over the VPN. This example will automatically append the VPC route, so this should only include extra routes to configure in addition to the VPC CIDR block."
  type        = list(string)
  default     = []
}

variable "vpn_search_domains" {
  description = "A list of domains to push down to the client to resolve over VPN. This will configure the OpenVPN server to pass through domains that should be resolved over the VPN connection (as opposed to the locally configured resolver) to the client. Note that for each domain, all subdomains will be resolved as well. E.g., if you pass in 'mydomain.local', subdomains such as 'hello.world.mydomain.local' and 'example.mydomain.local' will also be forwarded to through the VPN server."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to this instance."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "The type of instance to run for the OpenVPN Server"
  type        = string
  default     = "t3.micro"
}

variable "base_domain_name" {
  description = "The domain name in which to create the Route53 DNS record."
  type        = string
  default     = null
}

variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match var.domain_name."
  type        = map(string)
  default     = {}
}
