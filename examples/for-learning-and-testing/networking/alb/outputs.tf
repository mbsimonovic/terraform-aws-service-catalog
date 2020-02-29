output "alb_dns_name" {
  description = "The DNS record for the ALB."
  value       = module.alb.alb_dns_name
}

output "alb_access_logs_bucket" {
  description = "The name of the S3 bucket containing the ALB access logs"
  value       = module.alb.alb_access_logs_bucket
}
