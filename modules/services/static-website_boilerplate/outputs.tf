{{- if .IncludeCloudFront }}
output "cloudfront_domain_names" {
  value = [module.cloudfront.cloudfront_domain_names]
}

output "cloudfront_id" {
  value = module.cloudfront.cloudfront_id
}
{{- else }}
output "website_domain_name" {
  value = module.static_website.website_domain_name
}
{{- end }}

output "website_s3_bucket_arn" {
  value = module.static_website.website_bucket_arn
}

output "website_access_logs_bucket_arn" {
  value = module.static_website.access_logs_bucket_arn
}

output "cloudfront_access_logs_bucket_arn" {
  value = module.cloudfront.access_logs_bucket_arn
}
