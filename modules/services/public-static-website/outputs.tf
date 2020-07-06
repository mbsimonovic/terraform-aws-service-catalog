output "cloudfront_domain_names" {
  description = "The domain names created for the CloudFront Distribution. Should be the same as the input var.website_domain_name."
  value = module.cloudfront.cloudfront_domain_names
}

output "cloudfront_id" {
  description = "The CloudFront ID of the created CloudFront Distribution."
  value = module.cloudfront.cloudfront_id
}

output "website_s3_bucket_arn" {
  description = "The ARN of the created S3 bucket associated with the website."
  value = module.static_website.website_bucket_arn
}

output "website_access_logs_bucket_arn" {
  description = "The ARN of the created S3 bucket associated with the website access logs."
  value = module.static_website.access_logs_bucket_arn
}

output "cloudfront_access_logs_bucket_arn" {
  description = "The ARN of the created S3 bucket associated with the website's CloudFront access logs."
  value = module.cloudfront.access_logs_bucket_arn
}
