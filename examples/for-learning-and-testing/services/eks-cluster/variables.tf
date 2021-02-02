# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_instance_ami_version_tag" {
  description = "The version string of the AMI to run for the EKS workers built from the template in modules/services/eks-cluster/eks-node-al2.json. This corresponds to the value passed in for version_tag in the Packer template."
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

variable "enable_aws_auth_merger" {
  description = "If set to true, installs the aws-auth-merger to manage the aws-auth configuration. When true, requires setting the var.aws_auth_merger_image variable."
  type        = bool
  default     = false
}

variable "aws_auth_merger_image" {
  description = "Location of the container image to use for the aws-auth-merger app. You can use the Dockerfile provided in terraform-aws-eks to construct an image. See https://github.com/gruntwork-io/terraform-aws-eks/blob/master/modules/eks-aws-auth-merger/core-concepts.md#how-do-i-use-the-aws-auth-merger for more info."
  type = object({
    # Container image repository where the aws-auth-merger app container image lives
    repo = string
    # Tag of the aws-auth-merger container to deploy
    tag = string
  })
  default = null
}
