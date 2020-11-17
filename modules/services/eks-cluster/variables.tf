# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS resources will be deployed."
  type        = string
}

variable "control_plane_vpc_subnet_ids" {
  description = "List of IDs of the subnets that can be used for the EKS Control Plane."
  type        = list(string)
}

variable "autoscaling_group_configurations" {
  description = "Configure one or more Auto Scaling Groups (ASGs) to manage the EC2 instances in this cluster. If any of the values are not provided, the specified default variable will be used to lookup a default value."
  # Ideally, we will use a more strict type here but since we want to support required and optional values, and since
  # Terraform's type system only supports maps that have the same type for all values, we have to use the less useful
  # `any` type.
  type = any

  # Each configuration must be keyed by a unique string that will be used as a suffix for the ASG name. The values
  # support the following attributes:
  #
  # REQUIRED (must be provided for every entry):
  # - subnet_ids  list(string)  : A list of the subnets into which the EKS Cluster's worker nodes will be launched.
  #                               These should usually be all private subnets and include one in each AWS Availability
  #                               Zone. NOTE: If using a cluster autoscaler, each ASG may only belong to a single
  #                               availability zone.
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - min_size            number             : (Defaults to value from var.asg_default_min_size) The minimum number of
  #                                            EC2 Instances representing workers launchable for this EKS Cluster.
  #                                            Useful for auto-scaling limits.
  # - max_size            number             : (Defaults to value from var.asg_default_max_size) The maximum number of
  #                                            EC2 Instances representing workers that must be running for this EKS
  #                                            Cluster. We recommend making this at least twice the min_size, even if
  #                                            you don't plan on scaling the cluster up and down, as the extra capacity
  #                                            will be used to deploy updates to the cluster.
  # - asg_instance_type   string             : (Defaults to value from var.asg_default_instance_type) The type of
  #                                            instances to use for the ASG (e.g., t2.medium).
  # - tags                list(object[Tag])  : (Defaults to value from var.asg_default_tags) Custom tags to apply to the
  #                                            EC2 Instances in this ASG. Refer to structure definition below for the
  #                                            object type of each entry in the list.
  #
  # Structure of Tag object:
  # - key                  string  : The key for the tag to apply to the instance.
  # - value                string  : The value for the tag to apply to the instance.
  # - propagate_at_launch  bool    : Whether or not the tags should be propagated to the instance at launch time.
  #
  #
  # Example:
  # autoscaling_group_configurations = {
  #   "asg1" = {
  #     asg_instance_type = "t2.medium"
  #     subnet_ids        = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[0]]
  #   },
  #   "asg2" = {
  #     max_size          = 3
  #     asg_instance_type = "t2.large"
  #     subnet_ids        = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[1]]
  #
  #     tags = [{
  #       key                 = "size"
  #       value               = "large"
  #       propagate_at_launch = true
  #     }]
  #   }
  # }
}

variable "allow_inbound_api_access_from_cidr_blocks" {
  description = "The list of CIDR blocks to allow inbound access to the Kubernetes API."
  type        = list(string)
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template eks-node-al2.json. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required."
  type        = string
}

variable "cluster_instance_ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with self managed workers. You can build the AMI using the Packer template eks-node-al2.json. Only used if var.cluster_instance_ami is null. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required. Set to null if cluster_instance_ami is set."
  type = object({
    # List of owners to limit the search. Set to null if you do not wish to limit the search by AMI owners.
    owners = list(string)

    # Name/Value pairs to filter the AMI off of. There are several valid keys, for a full reference, check out the
    # documentation for describe-images in the AWS CLI reference
    # (https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html).
    filters = list(object({
      name   = string
      values = list(string)
    }))
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "schedule_control_plane_services_on_fargate" {
  description = "When true, configures control plane services to run on Fargate so that the cluster can run without worker nodes. When true, requires kubergrunt to be available on the system."
  type        = bool
  default     = false
}

variable "secret_envelope_encryption_kms_key_arn" {
  description = "ARN for KMS Key to use for envelope encryption of Kubernetes Secrets. By default Secrets in EKS are encrypted at rest using shared AWS managed keys. Setting this variable will configure Kubernetes to encrypt Secrets using this KMS key."
  type        = string
  default     = null
}

variable "worker_vpc_subnet_ids" {
  description = "A list of the subnets into which the EKS Cluster's administrative pods will be launched. These should usually be all private subnets and include one in each AWS Availability Zone. Required when var.schedule_control_plane_services_on_fargate is true."
  type        = list(string)
  default     = []
}

variable "allow_inbound_ssh_from_security_groups" {
  description = "The list of security group IDs to allow inbound SSH access to the worker groups."
  type        = list(string)
  default     = []
}

variable "allow_inbound_ssh_from_cidr_blocks" {
  description = "The list of CIDR blocks to allow inbound SSH access to the worker groups."
  type        = list(string)
  default     = []
}

variable "allow_private_api_access_from_cidr_blocks" {
  description = "The list of CIDR blocks to allow inbound access to the private Kubernetes API endpoint (e.g. the endpoint within the VPC, not the public endpoint)."
  type        = list(string)
  default     = []
}

variable "allow_private_api_access_from_security_groups" {
  description = "The list of security groups to allow inbound access to the private Kubernetes API endpoint (e.g. the endpoint within the VPC, not the public endpoint)."
  type        = list(string)
  default     = []
}

variable "enable_aws_auth_merger" {
  description = "If set to true, installs the aws-auth-merger to manage the aws-auth configuration. When true, requires setting the var.aws_auth_merger_image variable."
  type        = bool
  default     = false
}

variable "aws_auth_merger_image" {
  description = "Location of the container image to use for the aws-auth-merger app. You can use the Dockerfile provided in terraform-aws-eks to construct an image. See https://github.com/gruntwork-io/terraform-aws-eks/blob/master/modules/eks-aws-auth-merger/core-concepts.md#how-do-i-use-the-aws-auth-merger for more info."
  type = object({
    # Container image repository where the aws-auth-merger app container image lives
    repo = string
    # Tag of the aws-auth-merger container to deploy
    tag = string
  })
  default = null
}

variable "aws_auth_merger_namespace" {
  description = "Namespace to deploy the aws-auth-merger into. The app will watch for ConfigMaps in this Namespace to merge into the aws-auth ConfigMap."
  type        = string
  default     = "aws-auth-merger"
}

variable "enable_aws_auth_merger_fargate" {
  description = "When true, deploy the aws-auth-merger into Fargate. It is recommended to run the aws-auth-merger on Fargate to avoid chicken and egg issues between the aws-auth-merger and having an authenticated worker pool."
  type        = bool

  # Since we will manage the IAM role mapping for the workers using the merger, we need to schedule the deployment onto
  # Fargate. Otherwise, there is a chicken and egg problem where the workers won't be able to auth until the
  # aws-auth-merger is deployed, but the aws-auth-merger can't be deployed until the workers are setup. Fargate IAM
  # auth is automatically configured by AWS when we create the Fargate Profile, so we can break the cycle if we use
  # Fargate.
  default = true
}

variable "iam_role_to_rbac_group_mapping" {
  description = "Mapping of IAM role ARNs to Kubernetes RBAC groups that grant permissions to the user."
  type        = map(list(string))
  default     = {}

  # Example:
  # {
  #    "arn:aws:iam::ACCOUNT_ID:role/admin-role" = ["system:masters"]
  # }
}

variable "iam_user_to_rbac_group_mapping" {
  description = "Mapping of IAM user ARNs to Kubernetes RBAC groups that grant permissions to the user."
  type        = map(list(string))
  default     = {}

  # Example:
  # {
  #    "arn:aws:iam::ACCOUNT_ID:user/admin-user" = ["system:masters"]
  # }
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the EKS worker nodes when it is booting. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax. To override the default boot script installed as part of the module, use the key `default`."
  type = map(object({
    # A filename to report in the header for the part. Should be unique across all cloud-init parts.
    filename = string

    # A MIME-style content type to report in the header for the part. For example, use "text/x-shellscript" for a shell
    # script.
    content_type = string

    # The contents of the boot script to be called. This should be the full text of the script as a raw string.
    content = string
  }))
  default = {}
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to use. Refer to EKS docs for list of available versions (https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html)."
  type        = string
  default     = "1.17"
}

variable "endpoint_public_access" {
  description = "Whether or not to enable public API endpoints which allow access to the Kubernetes API from outside of the VPC. Note that private access within the VPC is always enabled."
  type        = bool
  default     = true
}

variable "external_account_ssh_grunt_role_arn" {
  description = "If you are using ssh-grunt and your IAM users / groups are defined in a separate AWS account, you can use this variable to specify the ARN of an IAM role that ssh-grunt can assume to retrieve IAM group and public SSH key info from that account. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the EKS workers. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = "ssh-grunt-users"
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the EKS workers with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Bastion host."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications."
  type        = list(string)
  default     = []
}

variable "enabled_control_plane_log_types" {
  description = "A list of the desired control plane logging to enable. See https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html for the list of available logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

# Properties of the EKS Cluster's EC2 Instances

variable "asg_default_min_size" {
  description = "Default value for the min_size field of autoscaling_group_configurations. Any map entry that does not specify min_size will use this value."
  type        = number
  default     = 1
}

variable "asg_default_max_size" {
  description = "Default value for the max_size field of autoscaling_group_configurations. Any map entry that does not specify max_size will use this value."
  type        = number
  default     = 2
}

variable "asg_default_instance_type" {
  description = "Default value for the asg_instance_type field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_type will use this value."
  type        = string
  default     = "t3.medium"
}

variable "asg_default_tags" {
  description = "Default value for the tags field of autoscaling_group_configurations. Any map entry that does not specify tags will use this value."
  type = list(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))
  default = []
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster"
  type        = string
  default     = null
}

variable "autoscaling_group_include_autoscaler_discovery_tags" {
  description = "Adds additional tags to each ASG that allow a cluster autoscaler to auto-discover them."
  type        = bool
  default     = true
}

# CloudWatch Dashboard Widgets

variable "dashboard_cpu_usage_widget_parameters" {
  description = "Parameters for the worker cpu usage widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_memory_usage_widget_parameters" {
  description = "Parameters for the worker memory usage widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_disk_usage_widget_parameters" {
  description = "Parameters for the worker disk usage widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# TEST PARAMETERS
# These variables exist solely for testing purposes.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_instance_associate_public_ip_address" {
  description = "Whether or not to associate a public IP address to the instances of the self managed ASGs. Will only work if the instances are launched in a public subnet."
  type        = bool
  default     = false
}
