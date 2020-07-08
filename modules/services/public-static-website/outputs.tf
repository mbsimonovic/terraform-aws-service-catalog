output "cloudfront_domain_names" {
  description = ""
  value = module.cloudfront.cloudfront_domain_names
}

output "cloudfront_id" {
  description = ""
  value = module.cloudfront.cloudfront_id
}

output "website_s3_bucket_arn" {
  description = ""
  value = module.static_website.website_bucket_arn
}

output "website_access_logs_bucket_arn" {
  description = ""
  value = module.static_website.access_logs_bucket_arn
}

output "cloudfront_access_logs_bucket_arn" {
  description = ""
  value = module.cloudfront.access_logs_bucket_arn
}
