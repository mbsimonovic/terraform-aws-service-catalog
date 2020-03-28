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
  description = "Configure one or more Auto Scaling Groups (ASGs) to manage the EC2 instances in this cluster. If you do not wish to use the default self managed ASG group, you can pass in an empty object (`{}`)."

  # Each configuration must be keyed by a unique string that will be used as a suffix for the ASG name.
  #
  # Example:
  # autoscaling_group_configurations = {
  #   "asg1" = {
  #     min_size   = 1
  #     max_size   = 3
  #     subnet_ids = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[0]]
  #     tags       = []
  #   },
  #   "asg2" = {
  #     min_size   = 1
  #     max_size   = 3
  #     subnet_ids = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[1]]
  #     tags       = []
  #   }
  # }
  type = map(object({
    # The minimum number of EC2 Instances representing workers launchable for this EKS Cluster. Useful for auto-scaling limits.
    min_size = number
    # The maximum number of EC2 Instances representing workers that must be running for this EKS Cluster.
    # We recommend making this at least twice the min_size, even if you don't plan on scaling the cluster up and down, as the extra capacity will be used to deploy udpates to the cluster.
    max_size = number

    # A list of the subnets into which the EKS Cluster's worker nodes will be launched.
    # These should usually be all private subnets and include one in each AWS Availability Zone.
    # NOTE: If using a cluster autoscaler, each ASG may only belong to a single availability zone.
    subnet_ids = list(string)

    # Custom tags to apply to the EC2 Instances in this ASG.
    # Each item in this list should be a map with the parameters key, value, and propagate_at_launch.
    #
    # Example:
    # [
    #   {
    #     key = "foo"
    #     value = "bar"
    #     propagate_at_launch = true
    #   },
    #   {
    #     key = "baz"
    #     value = "blah"
    #     propagate_at_launch = true
    #   }
    # ]
    tags = list(object({
      key                 = string
      value               = string
      propagate_at_launch = bool
    }))
  }))
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the EKS cluster (e.g. t3.medium)"
  type        = string
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template under packer/build.json."
  type        = string
}

variable "allow_inbound_api_access_from_cidr_blocks" {
  description = "The list of CIDR blocks to allow inbound access to the Kubernetes API."
  type        = list(string)
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

variable "worker_vpc_subnet_ids" {
  description = "A list of the subnets into which the EKS Cluster's administrative pods will be launched. These should usually be all private subnets and include one in each AWS Availability Zone. Required when var.schedule_control_plane_services_on_fargate is true."
  type        = list(string)
  default     = []
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster"
  type        = string
  default     = null
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
  default     = "1.15"
}

variable "endpoint_public_access" {
  description = "Whether or not to enable public API endpoints which allow access to the Kubernetes API from outside of the VPC."
  type        = bool
  default     = true
}

variable "external_account_ssh_grunt_role_arn" {
  description = "If you are using ssh-grunt and your IAM users / groups are defined in a separate AWS account, you can use this variable to specify the ARN of an IAM role that ssh-grunt can assume to retrieve IAM group and public SSH key info from that account. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the EKS workers. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the EKS workers with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Bastion host."
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
