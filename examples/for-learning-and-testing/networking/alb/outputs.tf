output "alb_dns_names" {
  description = "The DNS records for the ALB."
  value       = module.alb.alb_dns_names
}

output "alb_access_logs_bucket" {
  description = "The name of the S3 bucket containing the ALB access logs"
  value       = module.alb.alb_access_logs_bucket
}
