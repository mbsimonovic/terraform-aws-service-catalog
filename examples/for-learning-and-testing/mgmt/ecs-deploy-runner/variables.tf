# ------------------- -------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "docker_image_builder_config" {
  description = "Configuration options for the docker-image-builder container of the ECS deploy runner stack. This container will be used for building docker images in the CI/CD pipeline."
  type = object({
    # Docker repo and image tag to use as the container image for the docker image builder. This should be based on the
    # Dockerfile in terraform-aws-ci/modules/ecs-deploy-runner/docker/kaniko.
    container_image = object({
      docker_image = string
      docker_tag   = string
    })

    # An object defining the IAM policy statements to attach to the IAM role associated with the ECS task for the docker
    # image builder. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object
    # fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement.
    # Note that you do not need to explicitly grant read access to the secrets manager entries set on the other
    # variables (git_config and secrets_manager_env_vars).
    # iam_policy = {
    #   S3Access = {
    #     actions = ["s3:*"]
    #     resources = ["arn:aws:s3:::mybucket"]
    #     effect = "Allow"
    #   },
    #   EC2Access = {
    #     actions = ["ec2:*"],
    #     resources = ["*"]
    #     effect = "Allow"
    #   }
    # }
    iam_policy = map(object({
      resources = list(string)
      actions   = list(string)
      effect    = string
    }))

    # List of repositories that are allowed to build docker images. These should be the https git URL of the repository
    # (e.g., https://github.com/gruntwork-io/terraform-aws-ci.git).
    allowed_repos = list(string)

    # List of repositories (matching the regex) that are allowed to build AMIs. These should be the https git URL of the repository
    # (e.g., "https://github.com/gruntwork-io/.+" ).
    # Note that this is a list of individual regex because HCL doesn't allow bitwise operator: https://github.com/hashicorp/terraform/issues/25326
    allowed_repos_regex = list(string)

    # ARNs of AWS Secrets Manager entries that can be used for authenticating to HTTPS based git repos that contain the
    # Dockerfile for building the images. The associated user is recommended to be limited to read access only.
    #
    # Settings for each git service provider:
    #
    # Github:
    # - `username_secrets_manager_arn` should contain a valid Personal Access Token for the corresponding machine user.
    # - `password_secrets_manager_arn` should be set to null.
    #
    # BitBucket:
    # - `username_secrets_manager_arn` should contain the bitbucket username for the corresponding machine user.
    # - `password_secrets_manager_arn` should contain a valid App password for the corresponding machine user.
    #
    # GitLab:
    # - `username_secrets_manager_arn` should contain the hardcoded string "oauth2" (without the quotes).
    # - `password_secrets_manager_arn` should contain a valid Personal Access Token for the corresponding machine user.
    git_config = object({
      username_secrets_manager_arn = string
      password_secrets_manager_arn = string
    })

    # ARNs of AWS Secrets Manager entries that you would like to expose to the docker build process as environment
    # variables that can be passed in as build args. For example,
    # secrets_manager_env_vars = {
    #   GITHUB_OAUTH_TOKEN = "ARN_OF_PAT"
    # }
    # Will inject the secret value stored in the secrets manager entry ARN_OF_PAT as the env var `GITHUB_OAUTH_TOKEN`
    # in the container that can then be passed through to the docker build if you pass in
    # `--build-arg GITHUB_OAUTH_TOKEN`.
    secrets_manager_env_vars = map(string)

    # Map of environment variable names to values share with the container during runtime.
    # Do NOT use this for sensitive variables! Use secrets_manager_env_vars for secrets.
    environment_vars = map(string)
  })
}

variable "ami_builder_config" {
  description = "Configuration options for the ami-builder container of the ECS deploy runner stack. This container will be used for building AMIs in the CI/CD pipeline using packer."
  type = object({
    # Docker repo and image tag to use as the container image for the ami builder. This should be based on the
    # Dockerfile in terraform-aws-ci/modules/ecs-deploy-runner/docker/deploy-runner.
    container_image = object({
      docker_image = string
      docker_tag   = string
    })

    # An object defining the IAM policy statements to attach to the IAM role associated with the ECS task for the
    # ami builder. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object
    # fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement.
    # Note that you do not need to explicitly grant read access to the secrets manager entries set on the other
    # variables (repo_access_ssh_key_secrets_manager_arn and secrets_manager_env_vars).
    # iam_policy = {
    #   S3Access = {
    #     actions = ["s3:*"]
    #     resources = ["arn:aws:s3:::mybucket"]
    #     effect = "Allow"
    #   },
    #   EC2Access = {
    #     actions = ["ec2:*"],
    #     resources = ["*"]
    #     effect = "Allow"
    #   }
    # }
    iam_policy = map(object({
      resources = list(string)
      actions   = list(string)
      effect    = string
    }))

    # List of repositories that are allowed to build AMIs. These should be the SSH git URL of the repository
    # (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    allowed_repos = list(string)

    # List of repositories (matching the regex) that are allowed to build AMIs. These should be the SSH git URL of the repository
    # (e.g., "(git@github.com:gruntwork-io/)+" ).
    # Note that this is a list of individual regex because HCL doesn't allow bitwise operator: https://github.com/hashicorp/terraform/issues/25326
    allowed_repos_regex = list(string)

    # The ARN of a secrets manager entry containing the raw contents of a SSH private key to use when accessing remote
    # git repositories containing packer templates.
    repo_access_ssh_key_secrets_manager_arn = string

    # ARNs of AWS Secrets Manager entries that you would like to expose to the packer process as environment
    # variables. For example,
    # secrets_manager_env_vars = {
    #   GITHUB_OAUTH_TOKEN = "ARN_OF_PAT"
    # }
    # Will inject the secret value stored in the secrets manager entry ARN_OF_PAT as the env var `GITHUB_OAUTH_TOKEN`
    # in the container that can then be passed through to the AMI via the `env` directive in the packer template.
    secrets_manager_env_vars = map(string)

    # Map of environment variable names to values share with the container during runtime.
    # Do NOT use this for sensitive variables! Use secrets_manager_env_vars for secrets.
    environment_vars = map(string)
  })
}

variable "terraform_planner_config" {
  description = "Configuration options for the terraform-planner container of the ECS deploy runner stack. This container will be used for running infrastructure plan (including validate) actions in the CI/CD pipeline with Terraform / Terragrunt."
  type = object({
    # Docker repo and image tag to use as the container image for the ami builder. This should be based on the
    # Dockerfile in terraform-aws-ci/modules/ecs-deploy-runner/docker/deploy-runner.
    container_image = object({
      docker_image = string
      docker_tag   = string
    })

    # An object defining the IAM policy statements to attach to the IAM role associated with the ECS task for the
    # terraform planner. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object
    # fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement.
    # Note that you do not need to explicitly grant read access to the secrets manager entries set on the other
    # variables (repo_access_ssh_key_secrets_manager_arn and secrets_manager_env_vars).
    # iam_policy = {
    #   S3Access = {
    #     actions = ["s3:*"]
    #     resources = ["arn:aws:s3:::mybucket"]
    #     effect = "Allow"
    #   },
    #   EC2Access = {
    #     actions = ["ec2:*"],
    #     resources = ["*"]
    #     effect = "Allow"
    #   }
    # }
    iam_policy = map(object({
      resources = list(string)
      actions   = list(string)
      effect    = string
    }))

    # List of Git repository containing infrastructure live configuration (top level terraform or terragrunt
    # configuration to deploy infrastructure) that the deploy runner is allowed to run plan on. These should be the SSH
    # git URL of the repository (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    # NOTE: when only a single repository is provided, this will automatically be included as a hardcoded option.
    infrastructure_live_repositories = list(string)

    # List of Git repositories (matching the regex) containing infrastructure live configuration (top level terraform or terragrunt
    # configuration to deploy infrastructure) that the deploy runner is allowed to deploy. These should be the SSH git
    # URL of the repository (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    # Note that this is a list of individual regex because HCL doesn't allow bitwise operator: https://github.com/hashicorp/terraform/issues/25326
    infrastructure_live_repositories_regex = list(string)

    # The ARN of a secrets manager entry containing the raw contents of a SSH private key to use when accessing the
    # infrastructure live repository.
    repo_access_ssh_key_secrets_manager_arn = string

    # ARNs of AWS Secrets Manager entries that you would like to expose to the terraform/terragrunt process as
    # environment variables. For example,
    # secrets_manager_env_vars = {
    #   GITHUB_OAUTH_TOKEN = "ARN_OF_PAT"
    # }
    # Will inject the secret value stored in the secrets manager entry ARN_OF_PAT as the env var `GITHUB_OAUTH_TOKEN`
    # in the container that can then be accessed through terraform/terragrunt.
    secrets_manager_env_vars = map(string)

    # Map of environment variable names to values share with the container during runtime.
    # Do NOT use this for sensitive variables! Use secrets_manager_env_vars for secrets.
    environment_vars = map(string)
  })
}

variable "terraform_applier_config" {
  description = "Configuration options for the terraform-applier container of the ECS deploy runner stack. This container will be used for running infrastructure deployment actions (including automated variable updates) in the CI/CD pipeline with Terraform / Terragrunt."
  type = object({
    # Docker repo and image tag to use as the container image for the ami builder. This should be based on the
    # Dockerfile in terraform-aws-ci/modules/ecs-deploy-runner/docker/deploy-runner.
    container_image = object({
      docker_image = string
      docker_tag   = string
    })

    # An object defining the IAM policy statements to attach to the IAM role associated with the ECS task for the
    # terraform applier. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object
    # fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement.
    # Note that you do not need to explicitly grant read access to the secrets manager entries set on the other
    # variables (repo_access_ssh_key_secrets_manager_arn and secrets_manager_env_vars).
    # iam_policy = {
    #   S3Access = {
    #     actions = ["s3:*"]
    #     resources = ["arn:aws:s3:::mybucket"]
    #     effect = "Allow"
    #   },
    #   EC2Access = {
    #     actions = ["ec2:*"],
    #     resources = ["*"]
    #     effect = "Allow"
    #   }
    # }
    iam_policy = map(object({
      resources = list(string)
      actions   = list(string)
      effect    = string
    }))

    # List of Git repository containing infrastructure live configuration (top level terraform or terragrunt
    # configuration to deploy infrastructure) that the deploy runner is allowed to deploy. These should be the SSH git
    # URL of the repository (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    # NOTE: when only a single repository is provided, this will automatically be included as a hardcoded option.
    infrastructure_live_repositories = list(string)

    # List of Git repositories (matching the regex) containing infrastructure live configuration (top level terraform or terragrunt
    # configuration to deploy infrastructure) that the deploy runner is allowed to deploy. These should be the SSH git
    # URL of the repository (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    # Note that this is a list of individual regex because HCL doesn't allow bitwise operator: https://github.com/hashicorp/terraform/issues/25326
    infrastructure_live_repositories_regex = list(string)

    # List of variable names that are allowed to be automatically updated by the CI/CD pipeline. Recommended to set to:
    # ["tag", "docker_tag", "ami_version_tag", "ami"]
    allowed_update_variable_names = list(string)

    # A list of Git Refs (branch or tag) that are approved for running apply on. Any git ref that does not match this
    # list will not be allowed to run `apply` or `apply-all`. This is useful for protecting against internal threats
    # where users have access to the CI script and bypass the approval flow by commiting a new CI flow on their branch.
    # Set to null to allow all refs to apply.
    allowed_apply_git_refs = list(string)

    # User information to use when commiting updates to the infrastructure live configuration.
    machine_user_git_info = object({
      name  = string
      email = string
    })

    # The ARN of a secrets manager entry containing the raw contents of a SSH private key to use when accessing remote
    # repository containing the live infrastructure configuration. This SSH key should be for a machine user that has write
    # access to the code when using with terraform-update-variable.
    repo_access_ssh_key_secrets_manager_arn = string

    # ARNs of AWS Secrets Manager entries that you would like to expose to the terraform/terragrunt process as
    # environment variables. For example,
    # secrets_manager_env_vars = {
    #   GITHUB_OAUTH_TOKEN = "ARN_OF_PAT"
    # }
    # Will inject the secret value stored in the secrets manager entry ARN_OF_PAT as the env var `GITHUB_OAUTH_TOKEN`
    # in the container that can then be accessed through terraform/terragrunt.
    secrets_manager_env_vars = map(string)

    # Map of environment variable names to values share with the container during runtime.
    # Do NOT use this for sensitive variables! Use secrets_manager_env_vars for secrets.
    environment_vars = map(string)
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Name of this instance of the deploy runner stack. Used to namespace all resources."
  type        = string
  default     = "ecs-deploy-runner"
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "iam_roles" {
  description = "List of AWS IAM roles that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "iam_users" {
  description = "List of AWS IAM usernames that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "iam_groups" {
  description = "List of AWS IAM groups that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "enable_ec2_worker_pool" {
  description = "Whether or not to deploy a minimal EC2 worker pool for use with the ECS deploy runner. An EC2 worker pool supports caching of Docker images, so your builds may run faster, whereas Fargate is serverless, so you have no persistent EC2 instances to manage and pay for."
  type        = bool
  default     = false
}

variable "ec2_worker_pool_ami_version_tag" {
  description = "The version string of the AMI to run for the bastion host built from the template in modules/mgmt/ecs-deploy-runner/ecs-deploy-runner-worker-al2.json. This corresponds to the value passed in for version_tag in the Packer template. Only used if enable_ec2_worker_pool is true."
  type        = string
  default     = null
}

variable "container_default_launch_type" {
  description = "The default launch type of the ECS deploy runner workers. This launch type will be used if it is not overridden during invocation of the lambda function. Must be FARGATE or EC2."
  type        = string
  default     = "FARGATE"
}
