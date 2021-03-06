# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to create the ECR repositories in."
  type        = string
  default     = "eu-west-1"
}

variable "repositories" {
  description = "A map of repo names to configurations for that repository."
  # Ideally, we will use a more strict type here but since we want to support required and optional values, and since
  # Terraform's type system only supports maps that have the same type for all values, we have to use the less useful
  # `any` type.
  type = any

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - external_account_ids_with_read_access   list(string)             : List of account IDs that should have read
  #                                                                      access on the repo. If omitted, use
  #                                                                      var.default_external_account_ids_with_read_access.
  # - external_account_ids_with_write_access  list(string)             : List of account IDs that should have write
  #                                                                      access on the repo. If omitted, use
  #                                                                      var.default_external_account_ids_with_write_access.
  # - enable_automatic_image_scanning         bool                     : Whether or not to enable image scanning. If
  #                                                                      omitted use var.default_automatic_image_scanning.
  # - encryption_config                       object[EncryptionConfig] : Whether or not to enable encryption at rest for
  #                                                                      the container images, and how to encrypt. If
  #                                                                      omitted, use var.default_encryption_config. See
  #                                                                      below for the type schema.
  # - tags                                    map(string)              : Map of tags (where the key and value correspond
  #                                                                      to tag keys and values) that should be assigned
  #                                                                      to the ECR repository. Merged with
  #                                                                      var.global_tags.
  # Structure of EncryptionConfig object:
  # - encryption_type  string  : The encryption type to use for the repository. Must be AES256 or KMS.
  # - kms_key          string  : The KMS key to use for encrypting the images. Only used when encryption_type is KMS. If
  #                              not specified, defaults to the default AWS managed key for ECR.
  #
  #
  # Example:
  #
  # repositories = {
  #   myapp1 = {
  #     external_account_ids_with_read_access = ["11111111"]
  #   }
  # }

  default = {
    sample-application = {}
  }
}

variable "default_external_account_ids_with_read_access" {
  description = "The default list of AWS account IDs for external AWS accounts that should be able to pull images from these ECR repos. Can be overridden on a per repo basis by the external_account_ids_with_read_access property in the repositories map."
  type        = list(string)
  default     = []
}

variable "default_external_account_ids_with_write_access" {
  description = "The default list of AWS account IDs for external AWS accounts that should be able to pull and push images to these ECR repos. Can be overridden on a per repo basis by the external_account_ids_with_write_access property in the repositories map."
  type        = list(string)
  default     = []
}

variable "global_tags" {
  description = "A map of tags (where the key and value correspond to tag keys and values) that should be assigned to all ECR repositories."
  type        = map(string)
  default     = {}
}
