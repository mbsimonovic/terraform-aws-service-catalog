# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "website_domain_name" {
  description = "The name of the website and the S3 bucket to create (e.g. static.foo.com)."
  type        = string
}

variable "acm_certificate_domain_name" {
  description = "The domain name for which an ACM cert has been issued (e.g. *.foo.com). Only used if var.create_route53_entry is true. Set to blank otherwise."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------
variable "base_domain_name" {
  description = "The domain name associated with a hosted zone in Route 53. Usually the base domain name of var.website_domain_name (e.g. foo.com). This is used to find the hosted zone that will be used for the CloudFront distribution. If var.create_route53_entry is true, one of base_domain_name or var.hosted_zone_id must be provided."
  type        = string
  default     = null
}

variable "base_domain_name_tags" {
  description = "The tags associated with var.base_domain_name. If there are multiple hosted zones for the same base_domain_name, this will help filter the hosted zones so that the correct hosted zone is found."
  type        = map(any)
  default     = {}
}

variable "create_route53_entry" {
  description = "If set to true, create a DNS A Record in Route 53. If var.create_route53_entry is true, one of base_domain_name or var.hosted_zone_id must be provided."
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create the DNS A Records specified in var.website_domain_name. If var.create_route53_entry is true, one of base_domain_name or var.hosted_zone_id must be provided."
  type        = string
  default     = null
}

variable "index_document" {
  description = "The path to the index document in the S3 bucket (e.g. index.html)."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "The path to the error document in the S3 bucket (e.g. error.html)."
  type        = string
  default     = "error.html"
}

variable "default_ttl" {
  description = "The default amount of time, in seconds, that an object is in a CloudFront cache before CloudFront forwards another request in the absence of an 'Cache-Control max-age' or 'Expires' header."
  type        = number
  default     = 30
}

variable "max_ttl" {
  description = "The maximum amount of time, in seconds, that an object is in a CloudFront cache before CloudFront forwards another request to your origin to determine whether the object has been updated. Only effective in the presence of 'Cache-Control max-age', 'Cache-Control s-maxage', and 'Expires' headers."
  type        = number
  default     = 60
}

variable "min_ttl" {
  description = "The minimum amount of time that you want objects to stay in CloudFront caches before CloudFront queries your origin to see whether the object has been updated."
  type        = number
  default     = 0
}

variable "custom_tags" {
  description = "A map of custom tags to apply to the S3 bucket containing the website and the CloudFront distribution created for it. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "If set to true, this will force the delete of the website, redirect, and access log S3 buckets when you run terraform destroy, even if there is still content in those buckets. This is only meant for testing and should not be used in production."
  type        = bool
  default     = false
}
