variable "aws_region" {
  description = "The AWS region in which all resources will be created."
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "The name to use for the ASG and all other resources created by these templates"
  type        = string
  default     = "asg-example"
}

variable "ami" {
  description = "The ID of the AMI to run on each instance in the ASG"
  type        = string
  default     = "ami-04e80dcb9504b6979" // Ubuntu Server 18.04

}

variable "key_pair_name" {
  description = "An SSH Key Pair that can be used to connect to the EC2 Instance. This can be omitted entirely (set to an empty string) or used as an emergency backup mechanism in case ssh-grunt isn't working."
  type        = string
  default     = null
}