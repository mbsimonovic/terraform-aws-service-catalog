# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_instance_ami_id" {
  description = "The ID of the AMI to run for the EKS workers. Should be built from the Packer template in modules/services/eks-cluster/eks-node-al2.json."
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
  description = "Enter the name of the Jenkins server"
  type        = string
  default     = "eks-cluster"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the Jenkins server. Leave blank if you don't want to enable Key Pair auth."
  type        = string
  default     = null
}
