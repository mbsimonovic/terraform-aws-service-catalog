# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "eks_cluster_name" {
  description = "The name of the EKS cluster. The cluster must exist/already be deployed."
  type        = string
}

variable "autoscaling_group_configurations" {
  description = "Configure one or more self-managed Auto Scaling Groups (ASGs) to manage the EC2 instances in this cluster. Set to empty object ({}) if you do not wish to configure self-managed ASGs."
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
  # - asg_instance_root_volume_size   number : (Defaults to value from var.asg_default_instance_root_volume_size) The root volume size of
  #                                            instances to use for the ASG in GB (e.g., 40).
  # - asg_instance_root_volume_type   string : (Defaults to value from var.asg_default_instance_root_volume_type) The root volume type of
  #                                            instances to use for the ASG (e.g., "standard").
  # - asg_instance_root_volume_encryption   bool  : (Defaults to value from var.asg_default_instance_root_volume_encryption)
  #                                             Whether or not to enable root volume encryption for instances of the ASG.
  # - tags                list(object[Tag])  : (Defaults to value from var.asg_default_tags) Custom tags to apply to the
  #                                            EC2 Instances in this ASG. Refer to structure definition below for the
  #                                            object type of each entry in the list.
  # - use_multi_instances_policy   bool       : (Defaults to value from var.asg_default_use_multi_instances_policy)
  #                                             Whether or not to use a multi_instances_policy for the ASG.
  # - multi_instance_overrides     list(MultiInstanceOverride) : (Defaults to value from var.asg_default_multi_instance_overrides)
  #                                             List of multi instance overrides to apply. Each element in the list is
  #                                             an object that specifies the instance_type to use for the override, and
  #                                             the weighted_capacity.
  # - on_demand_allocation_strategy   string  : (Defaults to value from var.asg_default_on_demand_allocation_strategy)
  #                                             When using a multi_instances_policy the strategy to use when launching on-demand instances. Valid values: prioritized.
  # - on_demand_base_capacity   number        : (Defaults to value from var.asg_default_on_demand_base_capacity)
  #                                             When using a multi_instances_policy the absolute minimum amount of desired capacity that must be fulfilled by on-demand instances.
  # - on_demand_percentage_above_base_capacity   number : (Defaults to value from var.asg_default_on_demand_percentage_above_base_capacity)
  #                                             When using a multi_instances_policy the percentage split between on-demand and Spot instances above the base on-demand capacity.
  # - spot_allocation_strategy   string       : (Defaults to value from var.asg_default_spot_allocation_strategy)
  #                                             When using a multi_instances_policy how to allocate capacity across the Spot pools. Valid values: lowest-price, capacity-optimized.
  # - spot_instance_pools   number            : (Defaults to value from var.asg_default_spot_instance_pools)
  #                                             When using a multi_instances_policy the Number of Spot pools per availability zone to allocate capacity.
  #                                             EC2 Auto Scaling selects the cheapest Spot pools and evenly allocates Spot capacity across the number of Spot pools that you specify.
  # - spot_max_price   string                 : (Defaults to value from var.asg_default_spot_max_price, an empty string which means the on-demand price.)
  #                                             When using a multi_instances_policy the maximum price per unit hour that the user is willing to pay for the Spot instances.
  # - eks_kubelet_extra_args   string         : Extra args to pass to the kubelet process on node boot.
  # - cloud_init_parts    map(string)         : (Defaults to value from var.cloud_init_parts)
  #                                             Per-ASG cloud init scripts to run at boot time on the node.  See var.cloud_init_parts for accepted keys.
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

variable "managed_node_group_configurations" {
  description = "Configure one or more Node Groups to manage the EC2 instances in this cluster. Set to empty object ({}) if you do not wish to configure managed node groups."
  # Ideally, this would be a map of (string, object), with all the supported properties, but object does not support
  # optional properties. We can't use a map(any) either as that would require the values to all have the same type.
  type = any

  # Each configuration must be keyed by a unique string that will be used as a suffix for the node group name. The
  # values support the following attributes:
  #
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - subnet_ids          list(string)       : (Defaults to value from var.node_group_default_subnet_ids) A list of the
  #                                            subnets into which the EKS Cluster's managed nodes will be launched.
  #                                            These should usually be all private subnets and include one in each AWS
  #                                            Availability Zone. NOTE: If using a cluster autoscaler with EBS volumes,
  #                                            each ASG may only belong to a single availability zone.
  # - min_size            number             : (Defaults to value from var.node_group_default_min_size) The minimum
  #                                            number of EC2 Instances representing workers launchable for this EKS
  #                                            Cluster. Useful for auto-scaling limits.
  # - max_size            number             : (Defaults to value from var.node_group_default_max_size) The maximum
  #                                            number of EC2 Instances representing workers that must be running for
  #                                            this EKS Cluster. We recommend making this at least twice the min_size,
  #                                            even if you don't plan on scaling the cluster up and down, as the extra
  #                                            capacity will be used to deploy updates to the cluster.
  # - desired_size        number             : (Defaults to value from var.node_group_default_desired_size) The current
  #                                            desired number of EC2 Instances representing workers that must be running
  #                                            for this EKS Cluster.
  # - instance_types      list(string)       : (Defaults to value from var.node_group_default_instance_types) A list of
  #                                            instance types (e.g., t2.medium) to use for the EKS Cluster's worker
  #                                            nodes. EKS will choose from this list of instance types when launching
  #                                            new instances. When using launch templates, this setting will override
  #                                            the configured instance type of the launch template.
  # - capacity_type       string             : (Defaults to value from var.node_group_default_capacity_type) Type of capacity
  #                                            associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT.
  # - launch_template     LaunchTemplate     : (Defaults to value from var.node_group_default_launch_template)
  #                                            Launch template to use for the node. Specify either Name or ID of launch
  #                                            template. Must include version. Although the API supports using the
  #                                            values "$Latest" and "$Default" to configure the version, this can lead
  #                                            to a perpetual diff. Use the `latest_version` or `default_version` output
  #                                            of the aws_launch_template data source or resource instead. See
  #                                            https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#launch_template-configuration-block
  #                                            for more information.
  # - instance_root_volume_size   number     : (Defaults to value from var.node_group_default_instance_root_volume_size)
  #                                            The root volume size of instances to use for the ASG in GB (e.g., 40).
  # - instance_root_volume_type   string     : (Defaults to value from var.node_group_default_instance_root_volume_type)
  #                                            The root volume type of instances to use for the ASG (e.g., "standard").
  # - instance_root_volume_encryption  bool  : (Defaults to value from var.node_group_default_instance_root_volume_encryption)
  #                                             Whether or not to enable root volume encryption for instances of the ASG.
  # - tags                map(string)        : (Defaults to value from var.node_group_default_tags) Custom tags to apply
  #                                            to the EC2 Instances in this node group. This should be a key value pair,
  #                                            where the keys are tag keys and values are the tag values. Merged with
  #                                            var.common_tags.
  # - labels              map(string)        : (Defaults to value from var.node_group_default_labels) Custom Kubernetes
  #                                            Labels to apply to the EC2 Instances in this node group. This should be a
  #                                            key value pair, where the keys are label keys and values are the label
  #                                            values. Merged with var.common_labels.
  # - eks_kubelet_extra_args   string        : Extra args to pass to the kubelet process on node boot.
  # - cloud_init_parts    map(string)        : (Defaults to value from var.cloud_init_parts)
  #                                            Per-ASG cloud init scripts to run at boot time on the node.  See var.cloud_init_parts for accepted keys.
  #
  # Structure of LaunchTemplate object:
  # - name     string  : The Name of the Launch Template to use. One of ID or Name should be provided.
  # - id       string  : The ID of the Launch Template to use. One of ID or Name should be provided.
  # - version  string  : The version of the Launch Template to use.
  #
  # Example:
  # managed_node_group_configurations = {
  #   ngroup1 = {
  #     desired_size = 1
  #     min_size     = 1
  #     max_size     = 3
  #     subnet_ids  = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[0]]
  #   }
  #   asg2 = {
  #     desired_size   = 1
  #     min_size       = 1
  #     max_size       = 3
  #     subnet_ids     = [data.terraform_remote_state.vpc.outputs.private_app_subnet_ids[0]]
  #     disk_size      = 50
  #   }
  #   ngroup2 = {}  # Only defaults
  # }
}


variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template eks-node-al2.json. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required. Only used if var.cluster_instance_ami_filters is null. Set to null if cluster_instance_ami_filters is set."
  type        = string
}

variable "cluster_instance_ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with self managed workers. You can build the AMI using the Packer template eks-node-al2.json. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required. If both are defined, var.cluster_instance_ami_filters will be used. Set to null if cluster_instance_ami is set."
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

variable "worker_name_prefix" {
  description = "Prefix EKS worker resource names with this string. When you have multiple worker groups for the cluster, you can use this to namespace the resources. Defaults to empty string so that resource names are not excessively long by default."
  type        = string
  default     = ""
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

variable "custom_ingress_security_group_rules" {
  description = "A map of unique identifiers to ingress security group rules to attach to the worker groups."
  type = map(object({
    # The network ports and protocol (tcp, udp, all) for which the security group rule applies to.
    from_port = number
    to_port   = number
    protocol  = string

    # The source of the traffic. Only one of the following can be defined; the others must be configured to null.
    source_security_group_id = string       # The ID of the security group from which the traffic originates from.
    cidr_blocks              = list(string) # The list of IP CIDR blocks from which the traffic originates from.
  }))
  default = {}
}

variable "custom_egress_security_group_rules" {
  description = "A map of unique identifiers to egress security group rules to attach to the worker groups."
  type = map(object({
    # The network ports and protocol (tcp, udp, all) for which the security group rule applies to.
    from_port = number
    to_port   = number
    protocol  = string

    # The target of the traffic. Only one of the following can be defined; the others must be configured to null.
    target_security_group_id = string       # The ID of the security group to which the traffic goes to.
    cidr_blocks              = list(string) # The list of IP CIDR blocks to which the traffic goes to.
  }))
  default = {}
}

variable "aws_auth_merger_namespace" {
  description = "Namespace where the AWS Auth Merger is deployed. If configured, the worker IAM role will be mapped to the Kubernetes RBAC group for Nodes using a ConfigMap in the auth merger namespace."
  type        = string
  default     = null
}

variable "worker_k8s_role_mapping_name" {
  description = "Name of the IAM role to Kubernetes RBAC group mapping ConfigMap. Only used if aws_auth_merger_namespace is not null."
  type        = string
  default     = "eks-cluster-worker-iam-mapping"
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
  description = "The tenancy of the servers in the self-managed worker ASG. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
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
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent to get memory and disk metrics in CloudWatch for your Bastion host."
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


# Defaults for the Self-managed ASG configurations passed in through var.autoscaling_group_configurations. These values are used when
# the corresponding setting is omitted from the underlying map. Refer to the documentation under
# var.autoscaling_group_configurations for more on info on what each of these settings do.

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

variable "asg_default_instance_root_volume_size" {
  description = "Default value for the asg_instance_root_volume_size field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_root_volume_size will use this value."
  type        = number
  default     = 40
}

variable "asg_default_instance_root_volume_type" {
  description = "Default value for the asg_instance_root_volume_type field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_root_volume_type will use this value."
  type        = string
  default     = "standard"
}

variable "asg_default_instance_root_volume_encryption" {
  description = "Default value for the asg_instance_root_volume_encryption field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_root_volume_encryption will use this value."
  type        = bool
  default     = true
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

variable "asg_default_use_multi_instances_policy" {
  description = "Default value for the use_multi_instances_policy field of autoscaling_group_configurations. Any map entry that does not specify use_multi_instances_policy will use this value."
  type        = bool
  default     = false
}

variable "asg_default_on_demand_allocation_strategy" {
  description = "Default value for the on_demand_allocation_strategy field of autoscaling_group_configurations. Any map entry that does not specify on_demand_allocation_strategy will use this value."
  type        = string
  default     = null
}

variable "asg_default_on_demand_base_capacity" {
  description = "Default value for the on_demand_base_capacity field of autoscaling_group_configurations. Any map entry that does not specify on_demand_base_capacity will use this value."
  type        = number
  default     = null
}

variable "asg_default_on_demand_percentage_above_base_capacity" {
  description = "Default value for the on_demand_percentage_above_base_capacity field of autoscaling_group_configurations. Any map entry that does not specify on_demand_percentage_above_base_capacity will use this value."
  type        = number
  default     = null
}

variable "asg_default_spot_allocation_strategy" {
  description = "Default value for the spot_allocation_strategy field of autoscaling_group_configurations. Any map entry that does not specify spot_allocation_strategy will use this value."
  type        = string
  default     = null
}

variable "asg_default_spot_instance_pools" {
  description = "Default value for the spot_instance_pools field of autoscaling_group_configurations. Any map entry that does not specify spot_instance_pools will use this value."
  type        = number
  default     = null
}

variable "asg_default_spot_max_price" {
  description = "Default value for the spot_max_price field of autoscaling_group_configurations. Any map entry that does not specify spot_max_price will use this value. Set to empty string (default) to mean on-demand price."
  type        = string
  default     = null
}

variable "asg_default_multi_instance_overrides" {
  description = "Default value for the multi_instance_overrides field of autoscaling_group_configurations. Any map entry that does not specify multi_instance_overrides will use this value."
  default     = []

  # Ideally, we would use a concrete type here, but terraform doesn't support optional attributes yet, so we have to
  # resort to the untyped any.
  type = any

  # Example:
  # [
  #   {
  #     instance_type = "t3.micro"
  #     weighted_capacity = 2
  #   },
  #   {
  #     instance_type = "t3.medium"
  #     weighted_capacity = 1
  #   },
  # ]
}

variable "asg_iam_role_already_exists" {
  description = "Whether or not the IAM role used for the Self-managed workers already exists. When false, this module will create a new IAM role."
  type        = bool
  default     = false
}

variable "asg_custom_iam_role_name" {
  description = "Custom name for the IAM role for the Self-managed workers. When null, a default name based on worker_name_prefix will be used. One of asg_custom_iam_role_name and asg_iam_role_arn is required (must be non-null) if asg_iam_role_already_exists is true."
  type        = string
  default     = null
}

variable "asg_iam_role_arn" {
  description = "ARN of the IAM role to use if iam_role_already_exists = true. When null, uses asg_custom_iam_role_name to lookup the ARN. One of asg_custom_iam_role_name and asg_iam_role_arn is required (must be non-null) if asg_iam_role_already_exists is true."
  type        = string
  default     = null
}


# Defaults for the Node Group configurations passed in through var.managed_node_group_configurations. These values are used when
# the corresponding setting is omitted from the underlying map. Refer to the documentation under
# var.managed_node_group_configurations for more on info on what each of these settings do.

variable "node_group_default_subnet_ids" {
  description = "Default value for subnet_ids field of managed_node_group_configurations."
  type        = list(string)
  default     = null
}

variable "node_group_default_min_size" {
  description = "Default value for min_size field of managed_node_group_configurations."
  type        = number
  default     = 1
}

variable "node_group_default_max_size" {
  description = "Default value for max_size field of managed_node_group_configurations."
  type        = number
  default     = 1
}

variable "node_group_default_desired_size" {
  description = "Default value for desired_size field of managed_node_group_configurations."
  type        = number
  default     = 1
}

variable "node_group_launch_template_instance_type" {
  description = "The instance type to configure in the launch template. This value will be used when the instance_types field is set to null (NOT omitted, in which case var.node_group_default_instance_types will be used)."
  type        = string
  default     = null
}

variable "node_group_default_instance_types" {
  description = "Default value for instance_types field of managed_node_group_configurations."
  type        = list(string)
  default     = null
}

variable "node_group_default_capacity_type" {
  description = "Default value for capacity_type field of managed_node_group_configurations."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_default_tags" {
  description = "Default value for tags field of managed_node_group_configurations. Unlike common_tags which will always be merged in, these tags are only used if the tags field is omitted from the configuration."
  type        = map(string)
  default     = {}
}

variable "node_group_default_labels" {
  description = "Default value for labels field of managed_node_group_configurations. Unlike common_labels which will always be merged in, these labels are only used if the labels field is omitted from the configuration."
  type        = map(string)
  default     = {}
}

variable "node_group_default_instance_root_volume_size" {
  description = "Default value for the instance_root_volume_size field of managed_node_group_configurations."
  type        = number
  default     = 40
}

variable "node_group_default_instance_root_volume_type" {
  description = "Default value for the instance_root_volume_type field of managed_node_group_configurations."
  type        = string
  default     = "gp3"
}

variable "node_group_default_instance_root_volume_encryption" {
  description = "Default value for the instance_root_volume_encryption field of managed_node_group_configurations."
  type        = bool
  default     = true
}

# Ideally we don't need this variable, but for_each breaks when the values of the managed_node_group_configurations map depends
# on resources. To work around this, we allow the user to pass in the keys of the managed_node_group_configurations map
# separately.
variable "node_group_names" {
  description = "The names of the node groups. When null, this value is automatically calculated from the managed_node_group_configurations map. This variable must be set if any of the values of the managed_node_group_configurations map depends on a resource that is not available at plan time to work around terraform limitations with for_each."
  type        = list(string)
  default     = null
}

variable "managed_node_group_iam_role_already_exists" {
  description = "Whether or not the IAM role used for the Managed Node Group workers already exists. When false, this module will create a new IAM role."
  type        = bool
  default     = false
}

variable "managed_node_group_custom_iam_role_name" {
  description = "Custom name for the IAM role for the Managed Node Groups. When null, a default name based on worker_name_prefix will be used. One of managed_node_group_custom_iam_role_name and managed_node_group_iam_role_arn is required (must be non-null) if managed_node_group_iam_role_already_exists is true."
  type        = string
  default     = null
}

variable "managed_node_group_iam_role_arn" {
  description = "ARN of the IAM role to use if iam_role_already_exists = true. When null, uses managed_node_group_custom_iam_role_name to lookup the ARN. One of managed_node_group_custom_iam_role_name and managed_node_group_iam_role_arn is required (must be non-null) if managed_node_group_iam_role_already_exists is true."
  type        = string
  default     = null
}


# Properties of the EKS Cluster's EC2 Instances

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster."
  type        = string
  default     = null
}

variable "autoscaling_group_include_autoscaler_discovery_tags" {
  description = "Adds additional tags to each ASG that allow a cluster autoscaler to auto-discover them. Only used for self-managed workers."
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

# Kubernetes provider configuration parameters

variable "use_exec_plugin_for_auth" {
  description = "If this variable is set to true, then use an exec-based plugin to authenticate and fetch tokens for EKS. This is useful because EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy', and since the native Kubernetes provider in Terraform doesn't have a way to fetch up-to-date tokens, we recommend using an exec-based provider as a workaround. Use the use_kubergrunt_to_fetch_token input variable to control whether kubergrunt or aws is used to fetch tokens."
  type        = bool
  default     = true
}

variable "use_kubergrunt_to_fetch_token" {
  description = "EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To avoid this issue, we use an exec-based plugin to fetch an up-to-date token. If this variable is set to true, we'll use kubergrunt to fetch the token (in which case, kubergrunt must be installed and on PATH); if this variable is set to false, we'll use the aws CLI to fetch the token (in which case, aws must be installed and on PATH). Note this functionality is only enabled if use_exec_plugin_for_auth is set to true."
  type        = bool
  default     = true
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
