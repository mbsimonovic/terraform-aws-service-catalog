# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY JENKINS IN AN ASG, WITH AN ALB, ROUTE 53 DNS ENTRY, ACM TLS CERT, AND CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}


provider "aws" {
  region = var.aws_region
}

module "jenkins" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/jenkins?ref=v1.0.8"
  source = "../../../../modules/mgmt/jenkins"

  name          = var.name
  instance_type = "t3.small"
  memory        = "512m"
  ami           = null
  ami_filters = {
    owners = ["self"]
    filters = [
      {
        name   = "tag:service"
        values = ["jenkins-server"]
      },
      {
        name   = "tag:version"
        values = [var.ami_version_tag]
      },
    ]
  }


  # For this simple example, use a regular key pair instead of ssh-grunt
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets. In production,
  # you'll want to use a custom VPC, with Jenkins in a private subnet and the ALB in a public subnet.
  vpc_id            = data.aws_vpc.default.id
  jenkins_subnet_id = local.subnet_for_jenkins
  alb_subnet_ids    = data.aws_subnet_ids.default.ids

  # Configure a domain name for Jenkins
  hosted_zone_id             = data.aws_route53_zone.jenkins.id
  domain_name                = "${var.jenkins_subdomain}.${var.base_domain_name}"
  acm_ssl_certificate_domain = var.acm_ssl_certificate_domain

  # To keep this example simple, we make the ALB public and allow incoming HTTP and SSH connections from anywhere. In
  # production, you'll want to use an internal ALB and limit access to trusted servers only (e.g., solely a bastion
  # host or VPN server).
  is_internal_alb                      = false
  allow_incoming_http_from_cidr_blocks = ["0.0.0.0/0"]
  allow_ssh_from_cidr_blocks           = ["0.0.0.0/0"]

  # Jenkins server backup configuration
  backup_using_lambda            = var.backup_using_lambda
  backup_job_alarm_period        = var.backup_job_alarm_period
  backup_job_metric_name         = var.backup_job_metric_name
  backup_job_metric_namespace    = var.backup_job_metric_namespace
  backup_job_schedule_expression = var.backup_job_schedule_expression

  # DLM backup configuration
  backup_using_dlm                                      = var.backup_using_dlm
  dlm_backup_job_schedule_name                          = var.dlm_backup_job_schedule_name
  dlm_backup_job_schedule_interval                      = var.dlm_backup_job_schedule_interval
  dlm_backup_job_schedule_times                         = var.dlm_backup_job_schedule_times
  dlm_backup_job_schedule_number_of_snapshots_to_retain = var.dlm_backup_job_schedule_number_of_snapshots_to_retain
}
