# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------
variable "primary_bucket" {
  description = "What to name the S3 bucket. Note that S3 bucket names must be globally unique across all AWS users!"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "access_logging_bucket" {
  description = "The S3 bucket where access logs for this bucket should be stored. Set to null to disable access logging."
  type        = string
  default     = null
}

variable "bucket_policy_statements" {
  # The bucket policy statements for this S3 bucket. See the 'statement' block in the aws_iam_policy_document data
  # source for context: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
  #
  # bucket_policy_statements is a map where the keys are the statement IDs (SIDs) and the values are objects that can
  # define the following properties:
  #
  # - effect                                      string            (optional): Either "Allow" or "Deny", to specify whether this statement allows or denies the given actions.
  # - actions                                     list(string)      (optional): A list of actions that this statement either allows or denies. For example, ["s3:GetObject", "s3:PutObject"].
  # - not_actions                                 list(string)      (optional): A list of actions that this statement does NOT apply to. Used to apply a policy statement to all actions except those listed.
  # - principals                                  map(list(string)) (optional): The principals to which this statement applies. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - not_principals                              map(list(string)) (optional): The principals to which this statement does NOT apply. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - keys                                        list(string)      (optional): A list of keys within the bucket to which this policy applies. For example, ["", "/*"] would apply to (a) the bucket itself and (b) all keys within the bucket. The default is [""].
  # - condition                                   map(object)       (optional): A nested configuration block (described below) that defines a further, possibly-service-specific condition that constrains whether this statement applies.
  #
  # condition is a map from a unique ID for the condition to an object that can define the following properties:
  #
  # - test                                        string            (required): The name of the IAM condition operator to evaluate.
  # - variable                                    string            (required): The name of a Context Variable to apply the condition to. Context variables may either be standard AWS variables starting with aws:, or service-specific variables prefixed with the service name.
  # - values                                      list(string)      (required):  The values to evaluate the condition against. If multiple values are provided, the condition matches if at least one of them applies. (That is, the tests are combined with the "OR" boolean operation.)
  description = "The IAM policy to apply to this S3 bucket. You can use this to grant read/write access. This should be a map, where each key is a unique statement ID (SID), and each value is an object that contains the parameters defined in the comment above."

  # Ideally, this would be a map(object({...})), but the Terraform object type constraint doesn't support optional
  # parameters, whereas IAM policy statements have many optional params. And we can't even use map(any), as the
  # Terraform map type constraint requires all values to have the same type ("shape"), but as each object in the map
  # may specify different optional params, this won't work either. So, sadly, we are forced to fall back to "any."
  type = any

  # Example:
  #
  # {
  #    AllIamUsersReadAccess = {
  #      effect     = "Allow"
  #      actions    = ["s3:GetObject"]
  #      principals = {
  #        AWS = ["arn:aws:iam::111111111111:user/ann", "arn:aws:iam::111111111111:user/bob"]
  #      }
  #    }
  # }
  default = {}
}

variable "access_logging_bucket_policy_statements" {
  # The bucket policy statements for this access logging S3 bucket. See the 'statement' block in the aws_iam_policy_document data
  # source for context: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
  #
  # bucket_policy_statements is a map where the keys are the statement IDs (SIDs) and the values are objects that can
  # define the following properties:
  #
  # - effect                                      string            (optional): Either "Allow" or "Deny", to specify whether this statement allows or denies the given actions.
  # - actions                                     list(string)      (optional): A list of actions that this statement either allows or denies. For example, ["s3:GetObject", "s3:PutObject"].
  # - not_actions                                 list(string)      (optional): A list of actions that this statement does NOT apply to. Used to apply a policy statement to all actions except those listed.
  # - principals                                  map(list(string)) (optional): The principals to which this statement applies. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - not_principals                              map(list(string)) (optional): The principals to which this statement does NOT apply. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - keys                                        list(string)      (optional): A list of keys within the bucket to which this policy applies. For example, ["", "/*"] would apply to (a) the bucket itself and (b) all keys within the bucket. The default is [""].
  # - condition                                   map(object)       (optional): A nested configuration block (described below) that defines a further, possibly-service-specific condition that constrains whether this statement applies.
  #
  # condition is a map from a unique ID for the condition to an object that can define the following properties:
  #
  # - test                                        string            (required): The name of the IAM condition operator to evaluate.
  # - variable                                    string            (required): The name of a Context Variable to apply the condition to. Context variables may either be standard AWS variables starting with aws:, or service-specific variables prefixed with the service name.
  # - values                                      list(string)      (required):  The values to evaluate the condition against. If multiple values are provided, the condition matches if at least one of them applies. (That is, the tests are combined with the "OR" boolean operation.)
  description = "The IAM policy to apply to the S3 bucket used to store access logs. You can use this to grant read/write access. This should be a map, where each key is a unique statement ID (SID), and each value is an object that contains the parameters defined in the comment above."

  # Ideally, this would be a map(object({...})), but the Terraform object type constraint doesn't support optional
  # parameters, whereas IAM policy statements have many optional params. And we can't even use map(any), as the
  # Terraform map type constraint requires all values to have the same type ("shape"), but as each object in the map
  # may specify different optional params, this won't work either. So, sadly, we are forced to fall back to "any."
  type = any

  # Example:
  #
  # {
  #    AllIamUsersReadAccess = {
  #      effect     = "Allow"
  #      actions    = ["s3:GetObject"]
  #      principals = {
  #        AWS = ["arn:aws:iam::111111111111:user/ann", "arn:aws:iam::111111111111:user/bob"]
  #      }
  #    }
  # }
  default = {}
}

variable "replica_bucket_policy_statements" {
  # The bucket policy statements for this replica S3 bucket. See the 'statement' block in the aws_iam_policy_document data
  # source for context: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
  #
  # bucket_policy_statements is a map where the keys are the statement IDs (SIDs) and the values are objects that can
  # define the following properties:
  #
  # - effect                                      string            (optional): Either "Allow" or "Deny", to specify whether this statement allows or denies the given actions.
  # - actions                                     list(string)      (optional): A list of actions that this statement either allows or denies. For example, ["s3:GetObject", "s3:PutObject"].
  # - not_actions                                 list(string)      (optional): A list of actions that this statement does NOT apply to. Used to apply a policy statement to all actions except those listed.
  # - principals                                  map(list(string)) (optional): The principals to which this statement applies. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - not_principals                              map(list(string)) (optional): The principals to which this statement does NOT apply. The keys are the principal type ("AWS", "Service", or "Federated") and the value is a list of identifiers.
  # - keys                                        list(string)      (optional): A list of keys within the bucket to which this policy applies. For example, ["", "/*"] would apply to (a) the bucket itself and (b) all keys within the bucket. The default is [""].
  # - condition                                   map(object)       (optional): A nested configuration block (described below) that defines a further, possibly-service-specific condition that constrains whether this statement applies.
  #
  # condition is a map from a unique ID for the condition to an object that can define the following properties:
  #
  # - test                                        string            (required): The name of the IAM condition operator to evaluate.
  # - variable                                    string            (required): The name of a Context Variable to apply the condition to. Context variables may either be standard AWS variables starting with aws:, or service-specific variables prefixed with the service name.
  # - values                                      list(string)      (required):  The values to evaluate the condition against. If multiple values are provided, the condition matches if at least one of them applies. (That is, the tests are combined with the "OR" boolean operation.)
  description = "The IAM policy to apply to the replica S3 bucket. You can use this to grant read/write access. This should be a map, where each key is a unique statement ID (SID), and each value is an object that contains the parameters defined in the comment above."

  # Ideally, this would be a map(object({...})), but the Terraform object type constraint doesn't support optional
  # parameters, whereas IAM policy statements have many optional params. And we can't even use map(any), as the
  # Terraform map type constraint requires all values to have the same type ("shape"), but as each object in the map
  # may specify different optional params, this won't work either. So, sadly, we are forced to fall back to "any."
  type = any

  # Example:
  #
  # {
  #    AllIamUsersReadAccess = {
  #      effect     = "Allow"
  #      actions    = ["s3:GetObject"]
  #      principals = {
  #        AWS = ["arn:aws:iam::111111111111:user/ann", "arn:aws:iam::111111111111:user/bob"]
  #      }
  #    }
  # }
  default = {}
}

variable "enable_versioning" {
  description = "Set to true to enable versioning for this bucket. If enabled, instead of overriding objects, the S3 bucket will always create a new version of each object, so all the old values are retained."
  type        = bool
  default     = true
}

variable "mfa_delete" {
  description = "Enable MFA delete for either 'Change the versioning state of your bucket' or 'Permanently delete an object version'. This cannot be used to toggle this setting but is available to allow managed buckets to reflect the state in AWS. Only used if enable_versioning is true."
  type        = bool
  default     = true
}

variable "access_logging_prefix" {
  description = "A prefix (i.e., folder path) to use for all access logs stored in access_logging_bucket. Only used if access_logging_bucket is specified."
  type        = string
  default     = null
}

variable "replication_role" {
  description = "The ARN of the IAM role for Amazon S3 to assume when replicating objects. Only used if replication_bucket is specified."
  type        = string
  default     = null
}

variable "replication_rules" {
  # The replication rules for this S3 bucket. See the 'replication_configuration' block in the aws_s3_bucket resource
  # for context: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
  #
  # replication_rules is a map where the keys are the IDs of the rules and the values are objects that can define the
  # following properties:
  #
  # - status                                      string            (required): The status of the rule. Either Enabled or Disabled. The rule is ignored if status is not Enabled.
  # - priority                                    number            (optional): The priority associated with the rule.
  # - prefix                                      string            (optional): Object keyname prefix identifying one or more objects to which the rule applies.
  # - destination_bucket                          string            (required): The ARN of the S3 bucket where you want Amazon S3 to store replicas of the object identified by the rule.
  # - destination_storage_class                   string            (optional): The class of storage used to store the object. Can be STANDARD, REDUCED_REDUNDANCY, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER, or DEEP_ARCHIVE.
  # - destination_replica_kms_key_id              string            (optional): Destination KMS encryption key ARN for SSE-KMS replication. Must be used in conjunction with source_selection_criteria_enabled set to true.
  # - destination_access_control_translation      bool              (optional): If true, override the object owners on replication. Must be used in conjunction with destination_account_id owner override configuration.
  # - destination_account_id                      string            (optional): The Account ID to use for overriding the object owner on replication. Must be used in conjunction with destination_access_control_translation override configuration.
  # - source_selection_criteria_enabled           bool              (optional): Match SSE-KMS encrypted objects (documented below). If specified, destination_replica_kms_key_id in destination must be specified as well.
  # - filter                                      map(object)       (optional): Filter that identifies subset of objects to which the replication rule applies (documented below).
  #
  # filter is a map from a unique ID for the filter to an object that can define the following properties:
  #
  # - prefix                                      string            (optional): Object keyname prefix that identifies subset of objects to which the rule applies.
  # - tags                                        map(string)       (optional): A map of tags that identifies subset of objects to which the rule applies. The rule applies only to objects having all the tags in its tagset.
  description = "The rules for managing replication. Only used if replication_bucket is specified. This should be a map, where the key is a unique ID for each replication rule and the value is an object of the form explained in a comment above."

  # Ideally, this would be a list(object({...})), but the Terraform object type constraint doesn't support optional
  # parameters, whereas replication rules have many optional params. And we can't even use list(any), as the Terraform
  # list type constraint requires all values to have the same type ("shape"), but as each object in the list may specify
  # different optional params, this won't work either. So, sadly, we are forced to fall back to "any."
  type = any

  # Example:
  #
  # {
  #   ExampleConfig = {
  #     prefix                    = "config/"
  #     status                    = "Enabled"
  #     destination_bucket        = "arn:aws:s3:::my-destination-bucket"
  #     destination_storage_class = "STANDARD"
  #   }
  # }
  default = {}
}

variable "replica_bucket" {
  description = "The S3 bucket that will be the replica of this bucket. Set to null to disable replication."
  type        = string
  default     = null
}

variable "replica_region" {
  description = "The AWS region for the replica bucket."
  type        = string
  default     = null
}

variable "replica_bucket_already_exists" {
  description = "If set to true, replica bucket will be expected to already exist."
  type        = bool
  default     = false
}

variable "bucket_ownership" {
  description = "Configure who will be the default owner of objects uploaded to this S3 bucket: must be one of BucketOwnerPreferred (the bucket owner owns objects), ObjectWriter (the writer of each object owns that object), or null (don't configure this feature). Note that this setting only takes effect if the object is uploaded with the bucket-owner-full-control canned ACL. See https://docs.aws.amazon.com/AmazonS3/latest/dev/about-object-ownership.html for more info."
  type        = string
  default     = null
}

variable "access_logging_bucket_ownership" {
  description = "Configure who will be the default owner of objects uploaded to the access logs S3 bucket: must be one of BucketOwnerPreferred (the bucket owner owns objects), ObjectWriter (the writer of each object owns that object), or null (don't configure this feature). Note that this setting only takes effect if the object is uploaded with the bucket-owner-full-control canned ACL. See https://docs.aws.amazon.com/AmazonS3/latest/dev/about-object-ownership.html for more info."
  type        = string
  default     = null
}

variable "replica_bucket_ownership" {
  description = "Configure who will be the default owner of objects uploaded to the replica S3 bucket: must be one of BucketOwnerPreferred (the bucket owner owns objects), ObjectWriter (the writer of each object owns that object), or null (don't configure this feature). Note that this setting only takes effect if the object is uploaded with the bucket-owner-full-control canned ACL. See https://docs.aws.amazon.com/AmazonS3/latest/dev/about-object-ownership.html for more info."
  type        = string
  default     = null
}

variable "bucket_sse_algorithm" {
  description = "The server-side encryption algorithm to use on the bucket. Valid values are AES256 and aws:kms. Set to null to disable encryption."
  type        = string
  default     = "aws:kms"
}

variable "replica_sse_algorithm" {
  description = "The server-side encryption algorithm to use on the replica bucket. Valid values are AES256 and aws:kms."
  type        = string
  default     = "aws:kms"
}

variable "tags" {
  description = "A map of tags to apply to the S3 Bucket. These tags will also be applied to the access logging and replica buckets (if any). The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "force_destroy_primary" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the primary bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}

variable "force_destroy_logs" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the logs bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}

variable "force_destroy_replica" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the replica bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}
