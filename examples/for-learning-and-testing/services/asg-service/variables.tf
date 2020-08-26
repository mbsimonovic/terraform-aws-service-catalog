# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------
variable "ami" {
  description = "The ID of the AMI to run on each instance in the ASG. The AMI needs to have `ec2-baseline` installed, since by default it will run `start_ec2_baseline` on the User Data."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created."
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "The name to use for the ASG and all other resources created by these templates"
  type        = string
  default     = "asg-example"
}

variable "key_pair_name" {
  description = "An SSH Key Pair that can be used to connect to the EC2 Instances in the ASG. This can be omitted entirely (set to an empty string) or used as an emergency backup mechanism in case ssh-grunt isn't working."
  type        = string
  default     = null
}

variable "num_instances" {
  description = "The numbers of instances to be deployed into the ASG"
  type        = number
  default     = 2
}