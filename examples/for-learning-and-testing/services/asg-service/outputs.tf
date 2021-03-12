output "asg_name" {
  description = "The name of the auto scaling group."
  value       = module.asg.asg_name
}

output "lb_dns_name" {
  description = "The DNS name that can be used to reach the ALB that has been deployed using this module."
  value       = module.alb.alb_dns_names[0]
}

output "asg_unique_id" {
  description = "A unique ID common to all ASGs used for get_desired_capacity on new deploys."
  value       = module.asg.asg_unique_id
}

output "security_group_id" {
  description = "The ID of the Security Group that belongs to the ASG"
  value       = module.asg.security_group_id
}

output "launch_configuration_id" {
  description = "The ID of the launch configuration used for the ASG"
  value       = module.asg.launch_configuration_id
}

output "launch_configuration_name" {
  description = "The name of the launch configuration used for the ASG"
  value       = module.asg.launch_configuration_name
}
