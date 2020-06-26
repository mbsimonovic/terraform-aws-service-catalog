output "cloudfront_domain_names" {
  description = ""
  value = [module.static_website.cloudfront_domain_names]
}

output "cloudfront_id" {
  description = ""
  value = module.static_website.cloudfront_id
}

output "website_s3_bucket_arn" {
  description = ""
  value = module.static_website.website_s3_bucket_arn
}

output "website_access_logs_bucket_arn" {
  description = ""
  value = module.static_website.website_access_logs_bucket_arn
}

output "cloudfront_access_logs_bucket_arn" {
  description = ""
  value = module.static_website.cloudfront_access_logs_bucket_arn
}
