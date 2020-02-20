output "jenkins_asg_name" {
  value = module.jenkins.jenkins_asg_name
}

output "jenkins_security_group_id" {
  value = module.jenkins.jenkins_security_group_id
}

output "jenkins_iam_role_id" {
  value = module.jenkins.jenkins_iam_role_id
}

output "jenkins_iam_role_arn" {
  value = module.jenkins.jenkins_iam_role_arn
}

output "jenkins_domain_name" {
  value = module.jenkins.jenkins_domain_name
}
