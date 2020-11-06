output "primary_bucket_name" {
  description = "The name of the primary S3 bucket."
  value       = module.s3_bucket_primary.name
}

output "primary_bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = module.s3_bucket_primary.arn
}

output "primary_bucket_domain_name" {
  description = "The bucket domain name. Will be of format bucketname.s3.amazonaws.com."
  value       = module.s3_bucket_primary.bucket_domain_name
}

output "primary_bucket_regional_domain_name" {
  description = "The bucket region-specific domain name. The bucket domain name including the region name, please refer here for format. Note: The AWS CloudFront allows specifying S3 region-specific endpoint when creating S3 origin, it will prevent redirect issues from CloudFront to S3 Origin URL."
  value       = module.s3_bucket_primary.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region."
  value       = module.s3_bucket_primary.hosted_zone_id
}

output "access_logging_bucket_name" {
  description = "The name of the access logging S3 bucket."
  value       = module.s3_bucket_logs.name
}

output "replica_bucket_name" {
  description = "The name of the replica S3 bucket."
  value       = module.s3_bucket_replica.name
}
