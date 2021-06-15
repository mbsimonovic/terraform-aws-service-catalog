output "jenkins_asg_name" {
  value       = module.jenkins.jenkins_asg_name
  description = "The name of the Auto Scaling Group in which Jenkins is running"
}

output "jenkins_security_group_id" {
  value       = module.jenkins.jenkins_security_group_id
  description = "The ID of the Security Group attached to the Jenkins EC2 Instance"
}

output "jenkins_iam_role_id" {
  value       = module.jenkins.jenkins_iam_role_id
  description = "The ID of the IAM role attached to the Jenkins EC2 Instance"
}

output "jenkins_iam_role_arn" {
  value       = module.jenkins.jenkins_iam_role_arn
  description = "The ARN of the IAM role attached to the Jenkins EC2 Instance"
}

output "jenkins_ebs_volume_id" {
  value       = module.jenkins.jenkins_ebs_volume_id
  description = "The ID of the EBS Volume that will store the JENKINS_HOME directory"
}

output "alb_name" {
  value       = module.jenkins.alb_name
  description = "The name of the ALB deployed in front of Jenkins"
}

output "alb_arn" {
  value       = module.jenkins.alb_arn
  description = "The ARN of the ALB deployed in front of Jenkins"
}

output "alb_dns_name" {
  value       = module.jenkins.alb_dns_name
  description = "The DNS name of the ALB deployed in front of Jenkins"
}

output "alb_hosted_zone_id" {
  value       = module.jenkins.alb_hosted_zone_id
  description = "The hosted zone ID of the ALB deployed in front of Jenkins"
}

output "alb_security_group_id" {
  value       = module.jenkins.alb_security_group_id
  description = "The ID of the security group attached to the ALB deployed in front of Jenkins"
}

output "alb_listener_arns" {
  value       = module.jenkins.alb_listener_arns
  description = "The ARNs of the ALB listeners of the ALB deployed in front of Jenkins"
}

output "alb_http_listener_arns" {
  value       = module.jenkins.alb_http_listener_arns
  description = "The ARNs of just the HTTP ALB listeners of the ALB deployed in front of Jenkins"
}

output "alb_https_listener_non_acm_cert_arns" {
  value       = module.jenkins.alb_https_listener_non_acm_cert_arns
  description = "The ARNs of just the HTTPS ALB listeners that use non-ACM certs of the ALB deployed in front of Jenkins"
}

output "alb_https_listener_acm_cert_arns" {
  value       = module.jenkins.alb_https_listener_acm_cert_arns
  description = "The ARNs of just the HTTPS ALB listeners that usse ACM certs of the ALB deployed in front of Jenkins"
}

output "jenkins_domain_name" {
  value       = module.jenkins.jenkins_domain_name
  description = "The public domain name configured for Jenkins"
}

output "backup_lambda_function_name" {
  value = var.backup_using_lambda ? module.jenkins_backup[0].backup_lambda_function_name : null
}
