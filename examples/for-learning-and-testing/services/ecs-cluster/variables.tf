# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------
variable "cluster_instance_ami_id" {
  description = "The ID of the AMI to run for the ECS instances. Should be built from the Packer template in modules/services/ecs-cluster/packer/ecs-node.json"
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


