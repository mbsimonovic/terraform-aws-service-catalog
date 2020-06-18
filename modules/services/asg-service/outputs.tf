output "asg_name" {
  value = module.asg.asg_name
}

output "asg_unique_id" {
  value = module.asg.asg_unique_id
}

output "fully_qualified_domain_name" {
  value = element(concat(aws_route53_record.service.*.fqdn, [""]), 0)
}

output "security_group_id" {
  value = aws_security_group.lc_security_group.id
}

output "alb_listener_rule_ids" {
  value = aws_alb_listener_rule.paths_to_route_to_this_service.*.id
}

output "launch_configuration_id" {
  value = aws_launch_configuration.launch_configuration.id
}

output "launch_configuration_name" {
  value = aws_launch_configuration.launch_configuration.id
}
