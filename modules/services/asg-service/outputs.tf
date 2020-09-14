output "asg_name" {
  description = "The name of the auto scaling group."
  value       = module.asg.asg_name
}

output "asg_unique_id" {
  description = "A unique ID common to all ASGs used for get_desired_capacity on new deploys."
  value       = module.asg.asg_unique_id
}

output "fully_qualified_domain_name" {
  description = "The Fully Qualified Domain Name built using the zone domain and name."
  value       = element(concat(aws_route53_record.service.*.fqdn, [""]), 0)
}

output "security_group_id" {
  description = "The ID of the Security Group that belongs to the ASG."
  value       = aws_security_group.lc_security_group.id
}

output "lb_listener_rule_forward_arns" {
  description = "The ARNs of the rules of type forward. The key is the same key of the rule from the `forward_rules` variable."
  value       = module.listener_rules.lb_listener_rule_forward_arns
}

output "lb_listener_rule_fixed_response_arns" {
  description = "The ARNs of the rules of type fixed-response. The key is the same key of the rule from the `fixed_response_rules` variable."
  value       = module.listener_rules.lb_listener_rule_fixed_response_arns
}

output "lb_listener_rule_redirect_arns" {
  description = "The ARNs of the rules of type redirect. The key is the same key of the rule from the `redirect_rules` variable."
  value       = module.listener_rules.lb_listener_rule_redirect_arns
}

output "launch_configuration_id" {
  description = "The ID of the launch configuration used for the ASG."
  value       = aws_launch_configuration.launch_configuration.id
}

output "launch_configuration_name" {
  description = "The name of the launch configuration used for the ASG."
  value       = aws_launch_configuration.launch_configuration.id
}
