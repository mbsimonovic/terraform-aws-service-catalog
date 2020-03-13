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
  type = map(object({
    # List of account IDs that should have read access on the repo. When null, use var.default_external_account_ids_with_read_access.
    external_account_ids_with_read_access = list(string)
    # List of account IDs that should have write access on the repo. When null, use var.default_external_account_ids_with_write_access.
    external_account_ids_with_write_access = list(string)

    # Map of tags (where the key and value correspond to tag keys and values) that should be assigned to the ECR
    # repository. Merged with var.global_tags.
    tags = map(string)

    # Whether or not to enable image scanning.
    enable_automatic_image_scanning = bool
  }))
  default = {
    sample-application = {
      external_account_ids_with_read_access  = null
      external_account_ids_with_write_access = null
      tags                                   = {}
      enable_automatic_image_scanning        = true
    }
  }

  # Example:
  #
  # repositories = {
  #   myapp1 = {
  #     external_account_ids_with_read_access = ["11111111"]
  #     external_account_ids_with_write_access = null
  #     tags = {}
  #     enable_automatic_image_scanning = true
  #   }
  # }
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
