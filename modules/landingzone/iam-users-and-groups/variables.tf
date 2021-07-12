# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_account_id" {
  description = "The AWS Account ID the template should be operated on. This avoids misconfiguration errors caused by environment variables."
  type        = string
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL USERS MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "users" {
  description = "A map of users to create. The keys are the user names and the values are an object with the optional keys 'groups' (a list of IAM groups to add the user to), 'tags' (a map of tags to apply to the user), 'pgp_key' (either a base-64 encoded PGP public key, or a keybase username in the form keybase:username, used to encrypt the user's credentials; required if create_login_profile or create_access_keys is true), 'create_login_profile' (if set to true, create a password to login to the AWS Web Console), 'create_access_keys' (if set to true, create access keys for the user), 'path' (the path), and 'permissions_boundary' (the ARN of the policy that is used to set the permissions boundary for the user)."

  # Ideally, this would be a map of (string, object), but object does not support optional properties, and we want
  # users to be able to specify, say, tags for some users, but not for others. We can't use a map(any) either, as that
  # would require the values to all have the same type, and due to optional parameters, that wouldn't work either. So,
  # we have to lamely fall back to any.
  type = any

  # Example:
  # users = {
  #   alice = {
  #     groups = ["user-self-mgmt", "developers", "ssh-sudo-users"]
  #   }
  #
  #   bob = {
  #     path   = "/"
  #     groups = ["user-self-mgmt", "ops", "admins"]
  #     tags   = {
  #       foo = "bar"
  #     }
  #   }
  #
  #   carol = {
  #     groups               = ["user-self-mgmt", "developers", "ssh-users"]
  #     pgp_key              = "keybase:carol_on_keybase"
  #     create_login_profile = true
  #     create_access_keys   = true
  #   }
  # }

  default = {}
}

variable "force_destroy_users" {
  description = "When destroying this user, destroy even if it has non-Terraform-managed IAM access keys, login profile, or MFA devices. Without force_destroy a user with non-Terraform-managed access keys and login profile will fail to be destroyed."
  type        = bool
  default     = false
}

variable "password_reset_required" {
  description = "Force the user to reset their password on initial login. Only used for users with create_login_profile set to true."
  type        = bool
  default     = true
}

variable "minimum_password_length" {
  description = "Password minimum length."
  type        = number
  default     = 16
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL IAM-GROUPS PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_iam_groups" {
  description = "A feature flag to enable or disable the IAM Groups module."
  type        = bool
  default     = true
}

variable "should_require_mfa" {
  description = "Should we require that all IAM Users use Multi-Factor Authentication for both AWS API calls and the AWS Web Console? (true or false)"
  type        = bool
  default     = true
}

variable "iam_role_tags" {
  description = "The tags to apply to all the IAM role resources."
  type        = map(string)
  default     = {}
}

variable "cloudtrail_kms_key_arn" {
  description = "The ARN of a KMS CMK used to encrypt CloudTrail logs. If set, the logs group will include permissions to decrypt using this CMK."
  type        = string
  default     = null
}

variable "iam_group_developers_permitted_services" {
  description = "A list of AWS services for which the developers IAM Group will receive full permissions. See https://goo.gl/ZyoHlz to find the IAM Service name. For example, to grant developers access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]. Do NOT add iam to the list of services, or that will grant Developers de facto admin access. If you need to grant iam privileges, just grant the user Full Access."
  type        = list(string)
  default     = []
}

variable "iam_groups_for_cross_account_access" {
  description = "This variable is used to create groups that allow IAM users to assume roles in your other AWS accounts. It should be a list of objects, where each object has the fields 'group_name', which will be used as the name of the IAM group, and 'iam_role_arns', which is a list of ARNs of IAM Roles that you can assume when part of that group. For each entry in the list of objects, we will create an IAM group that allows users to assume the given IAM role(s) in the other AWS account. This allows you to define all your IAM users in one account (e.g. the users account) and to grant them access to certain IAM roles in other accounts (e.g. the stage, prod, audit accounts)."
  type = list(object({
    group_name    = string
    iam_role_arns = list(string)
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     group_name   = "stage-full-access"
  #     iam_role_arns = ["arn:aws:iam::123445678910:role/mgmt-full-access"]
  #   },
  #   {
  #     group_name   = "prod-read-only-access"
  #     iam_role_arns = [
  #       "arn:aws:iam::9876543210:role/prod-read-only-ec2-access",
  #       "arn:aws:iam::9876543210:role/prod-read-only-rds-access"
  #     ]
  #   }
  # ]
}

# The only IAM groups you typically need in the security account are full access (for admins) and groups that allows
# access to other AWS accounts
variable "should_create_iam_group_full_access" {
  description = "Should we create the IAM Group for full access? Allows full access to all AWS resources. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_billing" {
  description = "Should we create the IAM Group for billing? Allows read-write access to billing features only. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_support" {
  description = "Should we create the IAM Group for support? Allows support access (AWSupportAccess). (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_logs" {
  description = "Should we create the IAM Group for logs? Allows read access to CloudTrail, AWS Config, and CloudWatch. If var.cloudtrail_kms_key_arn is set, will also give decrypt access to a KMS CMK. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_developers" {
  description = "Should we create the IAM Group for developers? The permissions of that group are specified via var.iam_group_developers_permitted_services. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_read_only" {
  description = "Should we create the IAM Group for read-only? Allows read-only access to all AWS resources. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_user_self_mgmt" {
  description = "Should we create the IAM Group for user self-management? Allows users to manage their own IAM user accounts, but not other IAM users. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_iam_admin" {
  description = "Should we create the IAM Group for IAM administrator access? Allows users to manage all IAM entities, effectively granting administrator access. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_use_existing_iam_roles" {
  description = "Should we create the IAM Group for use-existing-iam-roles? Allow launching AWS resources with existing IAM Roles, but no ability to create new IAM Roles. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_auto_deploy" {
  description = "Should we create the IAM Group for auto-deploy? Allows automated deployment by granting the permissions specified in var.auto_deploy_permissions. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_houston_cli_users" {
  description = "Should we create the IAM Group for houston CLI users? Allows users to use the houston CLI for managing and deploying services."
  type        = bool
  default     = false
}

variable "should_create_iam_group_cross_account_access_all" {
  description = "Should we create the IAM Group for access to all external AWS accounts? "
  type        = bool
  default     = true
}

variable "iam_group_name_full_access" {
  description = "The name to be used for the IAM Group that grants full access to all AWS resources."
  type        = string
  default     = "full-access"
}

variable "iam_group_name_billing" {
  description = "The name to be used for the IAM Group that grants read/write access to all billing features in AWS."
  type        = string
  default     = "billing"
}

variable "iam_group_name_support" {
  description = "The name of the IAM Group that allows access to AWS Support."
  type        = string
  default     = "support"
}

variable "iam_group_name_logs" {
  description = "The name to be used for the IAM Group that grants read access to CloudTrail, AWS Config, and CloudWatch in AWS."
  type        = string
  default     = "logs"
}

variable "iam_group_name_developers" {
  description = "The name to be used for the IAM Group that grants IAM Users a reasonable set of permissions for developers."
  type        = string
  default     = "developers"
}

variable "iam_group_name_read_only" {
  description = "The name to be used for the IAM Group that grants read-only access to all AWS resources."
  type        = string
  default     = "read-only"
}

variable "iam_group_names_ssh_grunt_sudo_users" {
  description = "The list of names to be used for the IAM Group that enables its members to SSH as a sudo user into any server configured with the ssh-grunt Gruntwork module. Pass in multiple to configure multiple different IAM groups to control different groupings of access at the server level. Pass in empty list to disable creation of the IAM groups."
  type        = list(string)
  default     = ["ssh-grunt-sudo-users"]
}

variable "iam_group_names_ssh_grunt_users" {
  description = "The name to be used for the IAM Group that enables its members to SSH as a non-sudo user into any server configured with the ssh-grunt Gruntwork module. Pass in multiple to configure multiple different IAM groups to control different groupings of access at the server level. Pass in empty list to disable creation of the IAM groups."
  type        = list(string)
  default     = ["ssh-grunt-users"]
}

variable "iam_group_name_use_existing_iam_roles" {
  description = "The name to be used for the IAM Group that grants IAM Users the permissions to use existing IAM Roles when launching AWS Resources. This does NOT grant the permission to create new IAM Roles."
  type        = string
  default     = "use-existing-iam-roles"
}

variable "iam_group_name_auto_deploy" {
  description = "The name of the IAM Group that allows automated deployment by graning the permissions specified in var.auto_deploy_permissions."
  type        = string
  default     = "_machine.ecs-auto-deploy"
}

variable "iam_group_name_houston_cli" {
  description = "The name of the IAM Group that allows access to houston CLI."
  type        = string
  default     = "houston-cli-users"
}

variable "iam_group_name_iam_user_self_mgmt" {
  description = "The name to be used for the IAM Group that grants IAM Users the permissions to manage their own IAM User account."
  type        = string
  default     = "iam-user-self-mgmt"
}

variable "iam_policy_iam_user_self_mgmt" {
  description = "The name to be used for the IAM Policy that grants IAM Users the permissions to manage their own IAM User account."
  type        = string
  default     = "iam-user-self-mgmt"
}

variable "iam_group_name_iam_admin" {
  description = "The name to be used for the IAM Group that grants IAM administrative access. Effectively grants administrator access."
  type        = string
  default     = "iam-admin"
}

variable "cross_account_access_all_group_name" {
  description = "The name of the IAM group that will grant access to all external AWS accounts in var.iam_groups_for_cross_account_access."
  type        = string
  default     = "_all-accounts"
}

variable "auto_deploy_permissions" {
  description = "A list of IAM permissions (e.g. ec2:*) that will be added to an IAM Group for doing automated deployments. NOTE: If var.should_create_iam_group_auto_deploy is true, the list must have at least one element (e.g. '*')."
  type        = list(string)
  default     = []
}

variable "max_session_duration_human_users" {
  description = "The maximum allowable session duration, in seconds, for the credentials you get when assuming the IAM roles created by this module. This variable applies to all IAM roles created by this module that are intended for people to use, such as allow-read-only-access-from-other-accounts. For IAM roles that are intended for machine users, such as allow-auto-deploy-from-other-accounts, see var.max_session_duration_machine_users."
  type        = number
  default     = 43200 # 12 hours
}

variable "max_session_duration_machine_users" {
  description = "The maximum allowable session duration, in seconds, for the credentials you get when assuming the IAM roles created by this module. This variable  applies to all IAM roles created by this module that are intended for machine users, such as allow-auto-deploy-from-other-accounts. For IAM roles that are intended for human users, such as allow-read-only-access-from-other-accounts, see var.max_session_duration_human_users."
  type        = number
  default     = 3600 # 1 hour
}
