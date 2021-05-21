# ------------------- -------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where the ECS task and Lambda function should run."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of IDs of private subnets that can be used for running the ECS task and Lambda function."
  type        = list(string)
}

variable "docker_image_builder_config" {
  description = "Configuration options for the docker-image-builder container of the ECS deploy runner stack. This container will be used for building docker images in the CI/CD pipeline. Set to `null` to disable this container."
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
  description = "Configuration options for the ami-builder container of the ECS deploy runner stack. This container will be used for building AMIs in the CI/CD pipeline using packer. Set to `null` to disable this container."
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

    # List of repositories that are allowed to build docker images. These should be the SSH git URL of the repository
    # (e.g., git@github.com:gruntwork-io/terraform-aws-ci.git).
    allowed_repos = list(string)

    # List of repositories (matching the regex) that are allowed to build AMIs. These should be the SSH git URL of the repository
    # (e.g., "(git@github.com:gruntwork-io/)+" ).
    # Note that this is a list of individual regex because HCL doesn't allow bitwise operator: https://github.com/hashicorp/terraform/issues/25326
    allowed_repos_regex = list(string)

    # The ARN of a secrets manager entry containing the raw contents of a SSH private key to use when accessing remote
    # git repositories containing packer templates.
    repo_access_ssh_key_secrets_manager_arn = string

    # Configurations for setting up private git repo access to https based git URLs for each supported VCS platform.
    # The following keys are supported:
    #
    # - github_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitHub
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - gitlab_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitLab
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - bitbucket_token_secrets_manager_arn : The ARN of an AWS Secrets Manager entry containing contents of a BitBucket
    #                                         Personal Access Token for accessing git repos over HTTPS.
    #                                         bitbucket_username is required if this is set.
    # - bitbucket_username                  : The username of the BitBucket user associated with the bitbucket token
    #                                         passed in with bitbucket_token_secrets_manager_arn.
    repo_access_https_tokens = map(string)

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
  description = "Configuration options for the terraform-planner container of the ECS deploy runner stack. This container will be used for running infrastructure plan (including validate) actions in the CI/CD pipeline with Terraform / Terragrunt. Set to `null` to disable this container."
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

    # List of git repositories containing infrastructure live configuration (top level terraform or terragrunt
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

    # Configurations for setting up private git repo access to https based git URLs for each supported VCS platform.
    # The following keys are supported:
    #
    # - github_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitHub
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - gitlab_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitLab
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - bitbucket_token_secrets_manager_arn : The ARN of an AWS Secrets Manager entry containing contents of a BitBucket
    #                                         Personal Access Token for accessing git repos over HTTPS.
    #                                         bitbucket_username is required if this is set.
    # - bitbucket_username                  : The username of the BitBucket user associated with the bitbucket token
    #                                         passed in with bitbucket_token_secrets_manager_arn.
    repo_access_https_tokens = map(string)

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
  description = "Configuration options for the terraform-applier container of the ECS deploy runner stack. This container will be used for running infrastructure deployment actions (including automated variable updates) in the CI/CD pipeline with Terraform / Terragrunt. Set to `null` to disable this container."
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

    # Configurations for setting up private git repo access to https based git URLs for each supported VCS platform.
    # The following keys are supported:
    #
    # - github_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitHub
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - gitlab_token_secrets_manager_arn    : The ARN of an AWS Secrets Manager entry containing contents of a GitLab
    #                                         Personal Access Token for accessing git repos over HTTPS.
    # - bitbucket_token_secrets_manager_arn : The ARN of an AWS Secrets Manager entry containing contents of a BitBucket
    #                                         Personal Access Token for accessing git repos over HTTPS.
    #                                         bitbucket_username is required if this is set.
    # - bitbucket_username                  : The username of the BitBucket user associated with the bitbucket token
    #                                         passed in with bitbucket_token_secrets_manager_arn.
    repo_access_https_tokens = map(string)

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

variable "snapshot_encryption_kms_cmk_arns" {
  description = "Map of names to ARNs of KMS CMKs that are used to encrypt snapshots (including AMIs). This module will create the necessary KMS key grants to allow the respective deploy containers access to utilize the keys for managing the encrypted snapshots. The keys are arbitrary names that are used to identify the key."
  type        = map(string)
  default     = {}
}

variable "shared_secrets_enabled" {
  description = "If true, this module will create grants for a given shared secrets KMS key. You must pass a value for shared_secrets_kms_cmk_arn if this is set to true. Defaults to false."
  type        = bool
  default     = false
}

variable "shared_secrets_kms_cmk_arn" {
  description = "The ARN of the KMS CMK used for sharing AWS Secrets Manager secrets between accounts."
  type        = string
  default     = null
}

variable "container_cpu" {
  description = "The default CPU units for the instances that Fargate will spin up. The invoker allows users to override the CPU at run time, but this value will be used if the user provides no value for the CPU. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size."
  type        = number
  default     = 1024
}

variable "container_memory" {
  description = "The default memory units for the instances that Fargate will spin up. The invoker allows users to override the memory at run time, but this value will be used if the user provides no value for memory. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size."
  type        = number
  default     = 2048
}

variable "container_max_cpu" {
  description = "The maximum CPU units that is allowed to be specified by the user when invoking the deploy runner with the Lambda function."
  type        = number
  default     = 2048
}

variable "container_max_memory" {
  description = "The maximum memory units that is allowed to be specified by the user when invoking the deploy runner with the Lambda function."
  type        = number
  default     = 8192
}

variable "ec2_worker_pool_configuration" {
  description = "Worker configuration of a EC2 worker pool for the ECS cluster. An EC2 worker pool supports caching of Docker images, so your builds may run faster, whereas Fargate is serverless, so you have no persistent EC2 instances to manage and pay for. If null, no EC2 worker pool will be allocated and the deploy runner will be in Fargate only mode. Note that when this variable is set, this example module will automatically lookup and use the base ECS optimized AMI that AWS provides."
  # We use type any so that the user doesn't have to provide all of these values and we can use sane defaults.
  type    = any
  default = null

  # We expect the following attributes on this object:
  # - ami [string] (REQUIRED) : The ID of an AMI to use when deploying the instance. Either ami or ami_filters must be
  #                             provided.
  # - ami_filters [AMIFilter] (REQUIRED) : Properties on the AMI that can be used to lookup a prevuild AMI for use with
  #                                        the EC2 worker pool.
  # - min_size [number] (default: 1) : The minimum number of EC2 Instances launchable for this ECS Cluster. Useful for
  #                                    auto-scaling limits.
  # - max_size [number] (default: 2) : The maximum number of EC2 Instances that must be running for this ECS Cluster. We
  #                                    recommend making this twice min_size, even if you don't plan on scaling the
  #                                    cluster up and down, as the extra capacity will be used to deploy updates to the
  #                                    cluster.
  # - instance_type [string] (default: m5.large) : Instance type (e.g. t2.micro) to use for the EC2 instances. We
  #                                                recommend using at least large class instances.
  # - cloud_init_parts [map(CloudInitPart)] (default: {}) : Cloud init scripts to run on the host while it
  #                                                         boots. See the part blocks in
  #                                                         https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
  #                                                         for syntax.
  # - enable_cloudwatch_log_aggregation [bool] (default: true) : Whether or not to send server logs to the CloudWatch
  #                                                              Logs service.
  # - enable_cloudwatch_metrics [bool] (default: true) : Whether or not to send metrics to the CloudWatch service.
  # - enable_asg_cloudwatch_alarms [bool] (default: true) : Whether or not to configure cloudwatch alarms for the ASG.
  # - enable_fail2ban [bool] (default: true) : Whether or not to enable the fail2ban service on the server.
  # - enable_ip_lockdown [bool] (default: true) : Whether or not to enable the ip-lockdown service on the server.
  # - alarms_sns_topic_arn [string] (default: null) : The ARN of an SNS topic for cloudwatch to send alerts to.
  # - default_user [string] (default: ec2-user) : The default OS user that is created on the server.

  # Example:
  # ec2_worker_pool_configuration = {
  #   ami_filters = {
  #     owners = ["self"]
  #     filters = [{
  #       name   = "tag:version_tag"
  #       values = ["v0.20.4"]
  #     }]
  #   }
  # }
}

variable "container_default_launch_type" {
  description = "The default launch type of the ECS deploy runner workers. This launch type will be used if it is not overridden during invocation of the lambda function. Must be FARGATE or EC2."
  type        = string
  default     = "FARGATE"
}
