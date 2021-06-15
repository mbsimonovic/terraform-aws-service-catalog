# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_version_tag" {
  description = "The version string of the AMI to run for the Jenkins server built from the template in modules/mgmt/jenkins/jenkins-ubuntu.json. This corresponds to the value passed in for version_tag in the Packer template."
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

variable "backup_using_lambda" {
  description = "Set to true to backup the Jenkins Server using a Scheduled Lambda Function. If this variable is true, var.lambda_backup_schedule is required."
  type        = bool
  default     = true
}

variable "lambda_backup_schedule" {
  description = "An object representing the schedule for the execution of the Scheduled Lambda Function. Required when var.backup_using_lambda is true."
  type = object({
    # An expression that defines the schedule for how often to run the backup
    # lambda function. For example, cron(0 20 * * ? *) or rate(1 day).
    schedule_expression = string

    # How often, in seconds, the backup lambda function is expected to run.
    # This is the same as 'schedule_expression', but unfortunately, Terraform
    # offers no way to convert rate expressions to seconds. We add a CloudWatch
    # alarm that triggers if the value of 'metric_name' and
    # 'metric_namespace' isn't updated within this time period, as
    # that indicates the backup failed to run.
    alarm_period = number

    # The name for the CloudWatch Metric the AWS lambda backup function will
    # increment every time the job completes successfully.
    metric_name = string

    # The namespace for the CloudWatch Metric the AWS lambda backup function
    # will increment every time the job completes successfully.
    metric_namespace = string
  })
  default = {
    schedule_expression = "rate(1 day)"
    alarm_period        = 86400
    metric_name         = "jenkins-backup-job"
    metric_namespace    = "Custom/Jenkins"
  }
}
