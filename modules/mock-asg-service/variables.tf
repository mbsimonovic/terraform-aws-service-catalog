variable "vpc_id" {
  description = "The ID of the VPC to deploy into"
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI to deploy"
  type        = string
}

variable "cloud_init_parts" {
  description = "Cloud init scripts"
  type = map(object({
    content_type = string
    content      = string
  }))
  default = {}
}

variable "port" {
  description = "The port the service should listen on"
  type        = number
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}