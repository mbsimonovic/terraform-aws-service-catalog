# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_instance_ami_id" {
  description = "The ID of the AMI to run for the ECS instances. Should be built from the Packer template in modules/services/ecs-cluster/packer/ecs-node.json"
  type = string 
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS 
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into"
  type = string
  default = "eu-west-1"
}

variable "cluster_name" {
  description = "Enter the name of the ECS cluster"
  type = string 
  default = "ecs-cluster"
}

variable "keypair-name" {
  description = "The name of a Key Pair that can be used to SSH to the ECS cluster. Leave blank if you don't want to enable Key Pair auth"
  type = string 
  default = null 
}

