# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_instance_ami_version_tag" {
  description = "The version string of the AMI to run for the ECS workers built from the template in modules/services/ecs-cluster/ecs-node-al2.json. This corresponds to the value passed in for version_tag in the Packer template."
  type        = string
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS 
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Enter the name of the ECS cluster"
  type        = string
  default     = "ecs-cluster"
}

variable "cluster_instance_keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the ECS cluster. Leave blank if you don't want to enable Key Pair auth"
  type        = string
  default     = null
}

variable "cluster_max_size" {
  description = "The maximum number of EC2 instances that should be allowed to run within the ECS cluster at a given time"
  type        = string
  default     = null
}

variable "cluster_min_size" {
  description = "The minimum number of EC2 instances that should be allowed to run within the ECS cluster at a given time"
  type        = string
  default     = null
}

variable "cluster_instance_type" {
  description = "The EC2 instance type to use in the ECS cluster e.g., t2.micro"
  type        = string
  default     = "t2.micro"
}

variable "vpc_id" {
  description = "The ID of the VPC into which the ECS cluster resources should be launched"
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "The IDs of the VPC subnets into which the ECS cluster resources should be launched"
  type        = list(string)
  default     = []
}

variable "enable_ecs_cloudwatch_alarms" {
  description = "Set to true to enable cloudwatch monitoring and alarms on the ECS cluster"
  type        = bool
  default     = true
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the ECS nodes. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the ECS nodes with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to enable Cloudwatch log aggregation for the ECS cluster"
  type        = bool
  default     = false
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
