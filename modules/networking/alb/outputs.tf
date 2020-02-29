output "alb_name" {
  description = "A human friendly name for the ALB."
  value       = module.alb.alb_name
}

output "alb_arn" {
  description = "The ARN of the ALB resource."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "The DNS record for the ALB as specified in the input."
  value       = var.create_route53_entry ? join(",", aws_route53_record.dns_record.*.fqdn) : module.alb.alb_dns_name
}

output "original_alb_dns_name" {
  description = "The AWS-managed DNS name assigned to the ALB."
  value       = module.alb.alb_dns_name
}

output "alb_hosted_zone_id" {
  description = "The AWS-managed zone ID for the ALB's DNS record."
  value       = module.alb.alb_hosted_zone_id
}

output "alb_security_group_id" {
  description = "The ID of the security group associated with the ALB."
  value       = module.alb.alb_security_group_id
}

output "listener_arns" {
  description = "The map of listener ports to ARNs. This will include all listeners both HTTP and HTTPS."
  value       = module.alb.listener_arns
}

output "http_listener_arns" {
  description = "The map of HTTP listener ports to ARNs. There will be one listener per entry in var.http_listener_ports."
  value       = module.alb.http_listener_arns
}

output "https_listener_non_acm_cert_arns" {
  description = "The map of HTTPS listener ports to ARNs. There will be one listener per entry in var.https_listener_ports_and_ssl_certs."
  value       = module.alb.https_listener_non_acm_cert_arns
}

output "https_listener_acm_cert_arns" {
  description = "The map of HTTPS listener ports to ARNs. There will be one listener per entry in var.https_listener_ports_and_acm_ssl_certs."
  value       = module.alb.https_listener_acm_cert_arns
}

output "alb_access_logs_bucket" {
  description = "The name of the S3 bucket containing the ALB access logs"
  value       = module.alb_access_logs_bucket.s3_bucket_name
}
