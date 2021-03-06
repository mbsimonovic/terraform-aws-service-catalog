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

variable "routing_rules" {
  description = "A json array containing routing rules describing redirect behavior and when redirects are applied. For routing rule syntax, see: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-websiteconfiguration-routingrules.html. This will only be used if var.should_redirect_all_requests is false"
  type        = string
  default     = null
}

variable "viewer_protocol_policy" {
  description = "Use this element to specify the protocol that users can use to access the files in the origin specified by TargetOriginId when a request matches the path pattern in PathPattern. One of allow-all, https-only, or redirect-to-https."
  type        = string
  default     = "allow-all"
}

variable "geo_restriction_type" {
  description = "The method that you want to use to restrict distribution of your content by country: none, whitelist, or blacklist."
  type        = string
  default     = "none"
}

variable "geo_locations_list" {
  description = "The ISO 3166-1-alpha-2 codes for which you want CloudFront either to distribute your content (if var.geo_restriction_type is whitelist) or not distribute your content (if var.geo_restriction_type is blacklist)."
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "If set to true, this will force the delete of the website, redirect, and access log S3 buckets when you run terraform destroy, even if there is still content in those buckets. This is only meant for testing and should not be used in production."
  type        = bool
  default     = false
}
