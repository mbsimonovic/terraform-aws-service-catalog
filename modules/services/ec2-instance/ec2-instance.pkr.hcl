# ---------------------------------------------------------------------------------------------------------------------
# Packer settings
# ---------------------------------------------------------------------------------------------------------------------

packer {
  required_plugins {
    amazon = {
      version = ">= v1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED inputs
# ---------------------------------------------------------------------------------------------------------------------

variable "service_catalog_ref" {
  description = "Required. The version of the service catalog jenkins module to start from."
  type        = string
}

variable "version_tag" {
  description = "The value to use for the version tag that is created on the resulting AMI."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL inputs
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_name" {
  description = "The name to apply to the AMI. A timestamp is appended to the name to ensure uniqueness."
  type        = string
  default     = "ec2-instance"
}

variable "ami_users" {
  description = "A list of account IDs that can access the AMI."
  type        = list(string)
  default     = []
}

variable "availability_zone" {
  description = "The Availability Zone (e.g. us-east-1a, 1b, etc) in which to launch the instance."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "The region in which to search for the source AMI and in which to build the new AMI."
  type        = string
  default     = "eu-west-1"
}

variable "bash_commons_version" {
  description = "The version of github.com/gruntwork-io/bash-commons to install on the AMI."
  type        = string
  default     = ""
}

variable "copy_to_regions" {
  description = "A list of additional regions the AMI should be copied to. For encrypted AMIs, use `region_kms_key_ids` to provide the specific CMK to use for each region."
  type        = list(string)
  default     = []
}

variable "region_kms_key_ids" {
  description = "Map of regions to copy the ami to the custom kms key id (alias or arn) to use for encryption for that region. Note that each entry in the map must also have a corresponding entry in the `copy_to_regions` list. If set, encrypt_kms_key_id is ignored."
  type        = map(string)
  default     = {}

  # Example that will copy the resulting AMI to multiple regions and encrypt the AMI with that region's specified kms key:
  # copy_to_regions = ["us-east-1", "us-east-2", "ap-south-1"]
  # region_kms_key_ids = {
  #   "us-east-1" = "<us-east-1 ami encryption kms key id, alias, or ARN>"
  #   "us-east-2" = "<us-east-2 ami encryption kms key id, alias, or ARN>"
  #   "ap-south-1" = "<ap-south-1 ami encryption kms key id, alias, or ARN>"
  # }
  # https://www.packer.io/docs/builders/amazon/ebs#region_kms_key_ids
}

variable "enable_cloudwatch_log_aggregation" {
  description = "If true, install the CloudWatch agent for aggregating logs."
  type        = string
  default     = "true"
}

variable "enable_cloudwatch_metrics" {
  description = "If true, install the CloudWatch agent for collecting metrics."
  type        = string
  default     = "true"
}

variable "enable_ssh_grunt" {
  description = "Whether or not to install ssh-grunt."
  type        = string
  default     = "true"
}

variable "encrypt_boot" {
  description = "Whether or not to encrypt the AMI boot disk."
  type        = string
  default     = "false"
}

variable "encrypt_kms_key_id" {
  description = "The KMS key ID to use for encrypting the boot disk."
  type        = string
  default     = ""
}

variable "github_auth_token" {
  description = "The KMS key ID to use for encrypting the boot disk."
  type        = string
  default     = env("GITHUB_OAUTH_TOKEN")
  sensitive   = true
}

variable "gruntwork_installer_version" {
  description = "The GitHub OAUTH token to use for authenticating to GitHub with the gruntwork-installer."
  type        = string
  default     = "v0.0.34"
}

variable "instance_type" {
  description = "The instance type to use for building the AMI."
  type        = string
  default     = "t3.micro"
}

variable "module_aws_monitoring_version" {
  description = "The version of gruntwork-io/terraform-aws-monitoring to use."
  type        = string
  default     = ""
}

variable "module_ec2_baseline_branch" {
  description = "The branch of ec2-baseline to install (preferred over module_ec2_baseline_version)."
  type        = string
  default     = ""
}

variable "module_ec2_baseline_version" {
  description = "The version of ec2-baseline to install. If module_ec2_baseline_branch is set, that will be used instead."
  type        = string
  default     = ""
}

variable "module_persistent_ebs_volume_version" {
  description = "The version of gruntwork-io/terraform-aws-server to use for the persistent EBS data volume module."
  type        = string
  default     = ""
}

variable "module_security_version" {
  description = "The version of gruntwork-io/terraform-aws-security to use."
  type        = string
  default     = ""
}

variable "vpc_filter_key" {
  description = "The tag key to use for filtering which VPC the AMI should be built in. For example, 'Name' or 'isDefault' are possible values."
  type        = string
  default     = "isDefault"
}

variable "vpc_filter_value" {
  description = "The tag value to use for filtering which VPC the AMI should be built in. For example, 'prod' (value for Name tag key) or 'true' (for isDefault tag key) are possible values."
  type        = string
  default     = "true"
}

variable "vpc_subnet_filter_key" {
  description = "The tag key to use for filtering which subnet in which to build the AMI."
  type        = string
  default     = "default-for-az"
}

variable "vpc_subnet_filter_value" {
  description = "The tag value to use for filtering which subnet in which to build the AMI."
  type        = string
  default     = "true"
}

# ---------------------------------------------------------------------------------------------------------------------
# AMI lookup
# ---------------------------------------------------------------------------------------------------------------------

data "amazon-ami" "ubuntu-bionic" {
  filters = {
    architecture                       = "x86_64"
    "block-device-mapping.volume-type" = "gp2"
    name                               = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
    root-device-type                   = "ebs"
    virtualization-type                = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# Reusable source configuration
# ---------------------------------------------------------------------------------------------------------------------

source "amazon-ebs" "ubuntu-bionic" {
  ami_description             = "An Ubuntu AMI that is meant to be run as an EC2 instance."
  ami_name                    = "${var.ami_name}-${var.version_tag}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  ami_regions                 = var.copy_to_regions
  region_kms_key_ids          = var.region_kms_key_ids
  ami_users                   = var.ami_users
  associate_public_ip_address = true
  availability_zone           = var.availability_zone
  encrypt_boot                = var.encrypt_boot
  instance_type               = var.instance_type
  kms_key_id                  = var.encrypt_kms_key_id
  region                      = var.aws_region
  source_ami                  = data.amazon-ami.ubuntu-bionic.id
  ssh_username                = "ubuntu"
  tags = {
    service = var.ami_name
    version = var.version_tag
  }
  dynamic "vpc_filter" {
    for_each = var.vpc_filter_key != "" ? ["once"] : []
    content {
      filters = {
        (var.vpc_filter_key) = var.vpc_filter_value
      }
    }
  }
  dynamic "subnet_filter" {
    for_each = var.vpc_subnet_filter_key != "" ? ["once"] : []
    content {
      filters = {
        (var.vpc_subnet_filter_key) = var.vpc_subnet_filter_value
      }
      most_free = "true"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Builders and provisioners
# ---------------------------------------------------------------------------------------------------------------------

build {
  sources = ["source.amazon-ebs.ubuntu-bionic"]

  provisioner "shell" {
    environment_vars = [
      "GITHUB_OAUTH_TOKEN=${var.github_auth_token}",
      "module_security_version=${var.module_security_version}",
      "module_aws_monitoring_version=${var.module_aws_monitoring_version}",
      "module_ec2_baseline_version=${var.module_ec2_baseline_version}",
      "module_ec2_baseline_branch=${var.module_ec2_baseline_branch}",
      "module_persistent_ebs_volume_version=${var.module_persistent_ebs_volume_version}",
      "bash_commons_version=${var.bash_commons_version}",
      "enable_ssh_grunt=${var.enable_ssh_grunt}",
      "enable_cloudwatch_metrics=${var.enable_cloudwatch_metrics}",
      "enable_cloudwatch_log_aggregation=${var.enable_cloudwatch_log_aggregation}"
    ]
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install jq curl python3-pip nvme-cli",
      "curl -Ls https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh | bash /dev/stdin --version ${var.gruntwork_installer_version}",
      "gruntwork-install --module-name services/ec2-instance --repo https://github.com/gruntwork-io/terraform-aws-service-catalog --tag ${var.service_catalog_ref}"
    ]
    pause_before = "30s"
  }
}
