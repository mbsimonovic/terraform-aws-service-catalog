# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The ID of the AMI to run for Jenkins. Should be built from the Packer template in modules/mgmt/jenkins/jenkins-ubuntu.json."
  type        = string
}

variable "base_domain_name" {
  description = "The base domain (e.g., foo.com) in which to create a Route 53 A record for Jenkins. There must be a Route 53 Hosted Zone for this domain name."
  type        = string
}

variable "jenkins_subdomain" {
  description = "The subdomain of var.base_domain_name to create a DNS A record for Jenkins. E.g., If you set this to jenkins and var.base_domain_name to foo.com, this module will create an A record jenkins.foo.com."
  type        = string
}

variable "acm_ssl_certificate_domain" {
  description = "The domain name to use to find an ACM TLS certificate. This must be a TLS certificate that includes the Jenkins domain name in var.jenkins_subdomain: e.g., if var.jenkins_subdomain is jenkins, var.base_domain_name is foo.com, then this variable can be either jenkins.foo.com or *.foo.com."
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

variable "name" {
  description = "Enter the name of the Jenkins server"
  type        = string
  default     = "jenkins"
}

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the Jenkins server. Leave blank if you don't want to enable Key Pair auth."
  type        = string
  default     = null
}

variable "base_domain_name_tags" {
  description = "Tags to use to filter the Route 53 Hosted Zones that might match var.base_domain_name."
  type        = map(string)
  default     = {}
}