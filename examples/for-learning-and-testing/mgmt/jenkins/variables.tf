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

# Backup configuration

variable "backup_using_lambda" {
  description = "Set to true to backup the Jenkins Server using a Scheduled Lambda Function."
  type        = bool
  default     = false
}

variable "backup_job_metric_namespace" {
  description = "The namespace for the CloudWatch Metric the AWS lambda backup job will increment every time the job completes successfully."
  type        = string
  default     = "Custom/Jenkins"
}

variable "backup_job_metric_name" {
  description = "The name for the CloudWatch Metric the AWS lambda backup job will increment every time the job completes successfully."
  type        = string
  default     = "jenkins-backup-job"
}

variable "backup_job_schedule_expression" {
  description = "A cron or rate expression that specifies how often to take a snapshot of the Jenkins server for backup purposes. See https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html for syntax details."
  type        = string
  default     = "rate(1 day)"
}

variable "backup_job_alarm_period" {
  description = "How often, in seconds, the backup job is expected to run. This is the same as var.backup_job_schedule_expression, but unfortunately, Terraform offers no way to convert rate expressions to seconds. We add a CloudWatch alarm that triggers if the value of var.backup_job_metric_name and var.backup_job_metric_namespace isn't updated within this time period, as that indicates the backup failed to run."
  type        = number

  # One day in seconds
  default = 86400
}

variable "backup_using_dlm" {
  description = "Set to true to backup the Jenkins Server using AWS Data Lifecycle Management Policies."
  type        = bool
  default     = true
}

variable "dlm_backup_job_schedule_name" {
  description = "The name of the data lifecyle management schedule"
  type        = string
  default     = "daily-last-two-weeks"
}

variable "dlm_backup_job_schedule_interval" {
  description = "How often this lifecycle policy should be evaluated, in hours."
  type        = number
  default     = 24
}

variable "dlm_backup_job_schedule_times" {
  description = "A list of times in 24 hour clock format that sets when the lifecyle policy should be evaluated. Max of 1."
  type        = list(string)
  default     = ["03:00"]
}

variable "dlm_backup_job_schedule_number_of_snapshots_to_retain" {
  type        = number
  description = "How many snapshots to keep. Must be an integer between 1 and 1000."
  default     = 15
}
