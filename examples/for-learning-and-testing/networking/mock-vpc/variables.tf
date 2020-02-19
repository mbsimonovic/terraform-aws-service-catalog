variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "example-vpc"
}