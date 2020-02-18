output "service_url" {
  value = module.asg_service.service_url
}

output "cloud_init" {
  value = module.asg_service.cloud_init
}

output "instance_ip" {
  value = module.asg_service.instance_ip
}