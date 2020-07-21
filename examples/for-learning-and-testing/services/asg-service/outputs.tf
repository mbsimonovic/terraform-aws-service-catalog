output "asg_name" {
  value = module.asg.asg_name
}

output "lb_dns_name" {
  value = module.alb.alb_dns_name
}

output "asg_unique_id" {
  value = module.asg.asg_unique_id
}

output "fully_qualified_domain_name" {
  value = module.asg.fully_qualified_domain_name // TODO empty
}

output "security_group_id" {
  value = module.asg.security_group_id
}

output "launch_configuration_id" {
  value = module.asg.launch_configuration_id
}

output "launch_configuration_name" {
  value = module.asg.launch_configuration_name
}
