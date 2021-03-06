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

variable "allow_inbound_api_access_from_cidr_blocks" {
  description = "The list of CIDR blocks to allow inbound access to the Kubernetes API."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "schedule_control_plane_services_on_fargate" {
  description = "When true, configures control plane services to run on Fargate so that the cluster can run without worker nodes. If true, requires kubergrunt to be available on the system, and create_default_fargate_iam_role be set to true."
  type        = bool
  default     = false
}

variable "create_default_fargate_iam_role" {
  description = "When true, IAM role will be created and attached to Fargate control plane services."
  type        = bool
  default     = true
}

variable "custom_default_fargate_iam_role_name" {
  description = "The name to use for the default Fargate execution IAM role that is created when create_default_fargate_iam_role is true. When null, defaults to CLUSTER_NAME-fargate-role."
  type        = string
  default     = null
}

variable "secret_envelope_encryption_kms_key_arn" {
  description = "ARN for KMS Key to use for envelope encryption of Kubernetes Secrets. By default Secrets in EKS are encrypted at rest at the EBS layer in the managed etcd cluster using shared AWS managed keys. Setting this variable will configure Kubernetes to use envelope encryption to encrypt Secrets using this KMS key on top of the EBS layer encryption."
  type        = string
  default     = null
}

variable "worker_vpc_subnet_ids" {
  description = "A list of the subnets into which the EKS Cluster's administrative pods will be launched. These should usually be all private subnets and include one in each AWS Availability Zone. Required when var.schedule_control_plane_services_on_fargate is true."
  type        = list(string)
  default     = []
}

variable "num_worker_vpc_subnet_ids" {
  description = "Number of subnets provided in the var.worker_vpc_subnet_ids variable. When null (default), this is computed dynamically from the list. This is used to workaround terraform limitations where resource count and for_each can not depend on dynamic resources (e.g., if you are creating the subnets and the EKS cluster in the same module)."
  type        = number
  default     = null
}

variable "num_control_plane_vpc_subnet_ids" {
  description = "Number of subnets provided in the var.control_plane_vpc_subnet_ids variable. When null (default), this is computed dynamically from the list. This is used to workaround terraform limitations where resource count and for_each can not depend on dynamic resources (e.g., if you are creating the subnets and the EKS cluster in the same module)."
  type        = number
  default     = null
}

variable "control_plane_disallowed_availability_zones" {
  description = "A list of availability zones in the region that we CANNOT use to deploy the EKS control plane. You can use this to avoid availability zones that may not be able to provision the resources (e.g ran out of capacity). If empty, will allow all availability zones."
  type        = list(string)
  default = [
    # The following zones are known to not support EKS Control Plane.
    "us-east-1e",
  ]
}

variable "fargate_worker_disallowed_availability_zones" {
  description = "A list of availability zones in the region that we CANNOT use to deploy the EKS Fargate workers. You can use this to avoid availability zones that may not be able to provision the resources (e.g ran out of capacity). If empty, will allow all availability zones."
  type        = list(string)
  default = [
    # The following zones are known to not support EKS Fargate.
    "us-east-1d",
    "us-east-1e",
    "ca-central-1d",
  ]
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

variable "additional_security_groups_for_control_plane" {
  description = "A list of additional security group IDs to attach to the control plane."
  type        = list(string)
  default     = []
}

variable "additional_security_groups_for_workers" {
  description = "A list of additional security group IDs to attach to the worker nodes."
  type        = list(string)
  default     = []
}

variable "eks_cluster_tags" {
  description = "A map of custom tags to apply to the EKS Cluster Control Plane. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}

  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
}

variable "eks_cluster_security_group_tags" {
  description = "A map of custom tags to apply to the Security Group for the EKS Cluster Control Plane. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}

  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
}

variable "cluster_iam_role_permissions_boundary" {
  description = "ARN of permissions boundary to apply to the cluster IAM role - the IAM role created for the EKS cluster."
  type        = string
  default     = null
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

variable "aws_auth_merger_default_configmap_name" {
  description = "Name of the default aws-auth ConfigMap to use. This will be the name of the ConfigMap that gets created by this module in the aws-auth-merger namespace to seed the initial aws-auth ConfigMap."
  type        = string
  default     = "main-aws-auth"
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

variable "worker_iam_role_arns_for_k8s_role_mapping" {
  description = "List of ARNs of AWS IAM roles corresponding to EC2 instances that should be mapped as Kubernetes Nodes."
  type        = list(string)
  default     = []
}

variable "fargate_profile_executor_iam_role_arns_for_k8s_role_mapping" {
  description = "List of ARNs of AWS IAM roles corresponding to Fargate Profiles that should be mapped as Kubernetes Nodes."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to use. Refer to EKS docs for list of available versions (https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html)."
  type        = string
  default     = "1.21"
}

variable "endpoint_public_access" {
  description = "Whether or not to enable public API endpoints which allow access to the Kubernetes API from outside of the VPC. Note that private access within the VPC is always enabled."
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

variable "control_plane_cloudwatch_log_group_retention_in_days" {
  description = "The number of days to retain log events in the CloudWatch log group for EKS control plane logs. Refer to https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group#retention_in_days for all the valid values. When null, the log events are retained forever."
  type        = number
  default     = null
}

variable "control_plane_cloudwatch_log_group_kms_key_id" {
  description = "The ID (ARN, alias ARN, AWS ID) of a customer managed KMS Key to use for encrypting log data in the CloudWatch log group for EKS control plane logs."
  type        = string
  default     = null
}

variable "control_plane_cloudwatch_log_group_tags" {
  description = "Tags to apply on the CloudWatch Log Group for EKS control plane logs, encoded as a map where the keys are tag keys and values are tag values."
  type        = map(string)
  default     = null
}

# Properties of the EKS Cluster's EC2 Instances

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
# WORKER POOL PARAMETERS
# Configure these if you would like to manage your EKS cluster worker pool with the control plane.
# ---------------------------------------------------------------------------------------------------------------------

# VPC CNI Pod networking configurations for self-managed and managed node groups.

variable "vpc_cni_enable_prefix_delegation" {
  description = "When true, enable prefix delegation mode for the AWS VPC CNI component of the EKS cluster. In prefix delegation mode, each ENI will be allocated 16 IP addresses (/28) instead of 1, allowing you to pack more Pods per node. Note that by default, AWS VPC CNI will always preallocate 1 full prefix - this means that you can potentially take up 32 IP addresses from the VPC network space even if you only have 1 Pod on the node. You can tweak this behavior by configuring the var.vpc_cni_warm_ip_target input variable."
  type        = bool
  default     = true
}

variable "vpc_cni_warm_ip_target" {
  description = "The number of free IP addresses each node should maintain. When null, defaults to the aws-vpc-cni application setting (currently 16 as of version 1.9.0). In prefix delegation mode, determines whether the node will preallocate another full prefix. For example, if this is set to 5 and a node is currently has 9 Pods scheduled, then the node will NOT preallocate a new prefix block of 16 IP addresses. On the other hand, if this was set to the default value, then the node will allocate a new block when the first pod is scheduled."
  type        = number
  default     = null
}

variable "vpc_cni_minimum_ip_target" {
  description = "The minimum number of IP addresses (free and used) each node should start with. When null, defaults to the aws-vpc-cni application setting (currently 16 as of version 1.9.0). For example, if this is set to 25, every node will allocate 2 prefixes (32 IP addresses). On the other hand, if this was set to the default value, then each node will allocate only 1 prefix (16 IP addresses)."
  type        = number
  default     = null
}

# Configuration options common to both self-managed and managed worker types

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template eks-node-al2.json. One of var.cluster_instance_ami or var.cluster_instance_ami_filters is required. Only used if var.cluster_instance_ami_filters is null. Set to null if cluster_instance_ami_filters is set."
  type        = string
  default     = null
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
  default = null
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

variable "custom_worker_ingress_security_group_rules" {
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

variable "custom_worker_egress_security_group_rules" {
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

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster"
  type        = string
  default     = null
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

# Configuration options for self-managed EKS worker pool

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
  # - asg_instance_root_volume_size   number : (Defaults to value from var.asg_default_instance_root_volume_size) The root volume size of
  #                                            instances to use for the ASG in GB (e.g., 40).
  # - asg_instance_root_volume_type   string : (Defaults to value from var.asg_default_instance_root_volume_type) The root volume type of
  #                                            instances to use for the ASG (e.g., "standard").
  # - asg_instance_root_volume_iops   number : (Defaults to value from var.asg_default_instance_root_volume_iops) The root volume iops of
  #                                            instances to use for the ASG (e.g., 200).
  # - asg_instance_root_volume_throughput   number : (Defaults to value from var.asg_default_instance_root_volume_throughput) The root volume throughput in MiBPS of
  #                                            instances to use for the ASG (e.g., 125).
  # - asg_instance_root_volume_encryption   bool  : (Defaults to value from var.asg_default_instance_root_volume_encryption)
  #                                             Whether or not to enable root volume encryption for instances of the ASG.
  # - max_pods_allowed    number             : (Defaults to value from var.asg_default_max_pods_allowed) The
  #                                            maximum number of Pods allowed to be scheduled on the node. When null,
  #                                            the max will be automatically calculated based on the availability of
  #                                            total IP addresses to the instance type.
  # - tags                list(object[Tag])  : (Defaults to value from var.asg_default_tags) Custom tags to apply to the
  #                                            EC2 Instances in this ASG. Refer to structure definition below for the
  #                                            object type of each entry in the list.
  # - enable_detailed_monitoring   bool      : (Defaults to value from
  #                                            var.asg_default_enable_detailed_monitoring) Whether to enable
  #                                            detailed monitoring on the EC2 instances that comprise the ASG.
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
  # - eks_kubelet_extra_args        string    : Extra args to pass to the kubelet process on node boot.
  # - eks_bootstrap_script_options  string    : Extra option args to pass to the bootstrap.sh script. This will be
  #                                             passed through directly to the bootstrap script.
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
  default = {}
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "asg_iam_permissions_boundary" {
  description = "ARN of a permission boundary to apply on the IAM role created for the self managed workers."
  type        = string
  default     = null
}

variable "asg_iam_instance_profile_name" {
  description = "Custom name for the IAM instance profile for the Self-managed workers. When null, the IAM role name will be used. If var.asg_use_resource_name_prefix is true, this will be used as a name prefix."
  type        = string
  default     = null
}

variable "asg_security_group_tags" {
  description = "A map of tags to apply to the Security Group of the ASG for the self managed worker pool. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

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

variable "asg_default_instance_root_volume_iops" {
  description = "Default value for the asg_instance_root_volume_iops field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_root_volume_iops will use this value."
  type        = number
  default     = null
}

variable "asg_default_instance_root_volume_throughput" {
  description = "Default value for the asg_instance_root_volume_throughput field of autoscaling_group_configurations. Any map entry that does not specify asg_instance_root_volume_throughput will use this value."
  type        = number
  default     = null
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

variable "asg_default_max_pods_allowed" {
  description = "Default value for the max_pods_allowed field of autoscaling_group_configurations. Any map entry that does not specify max_pods_allowed will use this value."
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

variable "asg_default_enable_detailed_monitoring" {
  description = "Default value for enable_detailed_monitoring field of autoscaling_group_configurations."
  type        = bool
  default     = true
}

variable "autoscaling_group_include_autoscaler_discovery_tags" {
  description = "Adds additional tags to each ASG that allow a cluster autoscaler to auto-discover them."
  type        = bool
  default     = true
}

# Configuration options for Managed Node Group EKS worker pool

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
  # - max_pods_allowed    number             : (Defaults to value from var.node_group_default_max_pods_allowed) The
  #                                            maximum number of Pods allowed to be scheduled on the node. When null,
  #                                            the max will be automatically calculated based on the availability of
  #                                            total IP addresses to the instance type.
  # - tags                map(string)        : (Defaults to value from var.node_group_default_tags) Custom tags to apply
  #                                            to the EC2 Instances in this node group. This should be a key value pair,
  #                                            where the keys are tag keys and values are the tag values. Merged with
  #                                            var.common_tags.
  # - labels              map(string)        : (Defaults to value from var.node_group_default_labels) Custom Kubernetes
  #                                            Labels to apply to the EC2 Instances in this node group. This should be a
  #                                            key value pair, where the keys are label keys and values are the label
  #                                            values. Merged with var.common_labels.
  # - enable_detailed_monitoring    bool     : (Defaults to value from
  #                                            var.node_group_default_enable_detailed_monitoring) Whether to enable
  #                                            detailed monitoring on the EC2 instances that comprise the Managed node
  #                                            group.
  # - eks_kubelet_extra_args        string   : Extra args to pass to the kubelet process on node boot.
  # - eks_bootstrap_script_options  string   : Extra option args to pass to the bootstrap.sh script. This will be
  #                                            passed through directly to the bootstrap script.
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
  default = {}
}

variable "node_group_iam_permissions_boundary" {
  description = "ARN of a permission boundary to apply on the IAM role created for the managed node groups."
  type        = string
  default     = null
}

variable "node_group_security_group_tags" {
  description = "A map of tags to apply to the Security Group of the ASG for the managed node group pool. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

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

variable "node_group_default_enable_detailed_monitoring" {
  description = "Default value for enable_detailed_monitoring field of managed_node_group_configurations."
  type        = bool
  default     = true
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

variable "node_group_default_max_pods_allowed" {
  description = "Default value for the max_pods_allowed field of managed_node_group_configurations. Any map entry that does not specify max_pods_allowed will use this value."
  type        = number
  default     = null
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
# OPTIONAL PARAMETERS WITH RECOMMENDED DEFAULTS
# These values shouldn't be changed unless you are testing things or you have good reasons to adjust these flags. All of
# these flags are optimized for production based workflows and adjustments can either disrupt your workflows to require
# manual work arounds or make the module more brittle.
# ---------------------------------------------------------------------------------------------------------------------

variable "use_kubergrunt_verification" {
  description = "When set to true, this will enable kubergrunt verification to wait for the Kubernetes API server to come up before completing. If false, reverts to a 30 second timed wait instead."
  type        = bool
  default     = true
}

variable "use_kubergrunt_sync_components" {
  description = "When set to true, this will enable kubergrunt based component syncing. This step ensures that the core EKS components that are installed are upgraded to a matching version everytime the cluster's Kubernetes version is updated."
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

# ---------------------------------------------------------------------------------------------------------------------
# BACKWARD COMPATIBILITY FEATURE FLAGS
# The following variables are feature flags to enable and disable certain features in the module. These are primarily
# introduced to maintain backward compatibility by avoiding unnecessary resource creation.
# ---------------------------------------------------------------------------------------------------------------------

variable "asg_use_resource_name_prefix" {
  description = "When true, all the relevant resources for self managed workers will be set to use the name_prefix attribute so that unique names are generated for them. This allows those resources to support recreation through create_before_destroy lifecycle rules. Set to false if you were using any version before 0.65.0 and wish to avoid recreating the entire worker pool on your cluster."
  type        = bool
  default     = true
}

variable "use_vpc_cni_customize_script" {
  description = "When set to true, this will enable management of the aws-vpc-cni configuration options using kubergrunt running as a local-exec provisioner. If you set this to false, the vpc_cni_* variables will be ignored."
  type        = bool
  default     = true
}

variable "should_create_control_plane_cloudwatch_log_group" {
  description = "When true, precreate the CloudWatch Log Group to use for EKS control plane logging. This is useful if you wish to customize the CloudWatch Log Group with various settings such as retention periods and KMS encryption. When false, EKS will automatically create a basic log group to use. Note that logs are only streamed to this group if var.enabled_cluster_log_types is true."
  type        = bool
  default     = true
}

variable "use_managed_iam_policies" {
  description = "When true, all IAM policies will be managed as dedicated policies rather than inline policies attached to the IAM roles. Dedicated managed policies are friendlier to automated policy checkers, which may scan a single resource for findings. As such, it is important to avoid inline policies when targeting compliance with various security standards."
  type        = bool
  default     = true
}

locals {
  use_inline_policies = var.use_managed_iam_policies == false
}
