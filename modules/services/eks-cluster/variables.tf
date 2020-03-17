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

variable "worker_vpc_subnet_ids" {
  description = "List of IDs of the subnets that can be used for the EKS workers."
  type        = list(string)
}

variable "cluster_min_size" {
  description = "The minimum number of instances to run in the EKS cluster"
  type        = number
}

variable "cluster_max_size" {
  description = "The maxiumum number of instances to run in the EKS cluster"
  type        = number
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the EKS cluster (e.g. t3.medium)"
  type        = string
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the EKS cluster. You can build the AMI using the Packer template under packer/build.json."
  type        = string
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the EKS cluster"
  type        = string
}

variable "allow_inbound_api_access_from_cidrs" {
  description = "The list of CIDR blocks to allow inbound access to the Kubernetes API."
  type        = list(string)
}

variable "allow_inbound_ssh_from_security_groups" {
  description = "The list of security group IDs to allow inbound SSH access to the worker groups."
  type        = list(string)
}

variable "iam_role_to_rbac_group_mapping" {
  description = "Mapping of IAM role ARNs to Kubernetes RBAC groups that grant permissions to the user."
  type        = map(list(string))

  # Example:
  # {
  #    "arn:aws:iam::ACCOUNT_ID:role/admin-role" = ["system:masters"]
  # }
}

variable "iam_user_to_rbac_group_mapping" {
  description = "Mapping of IAM user ARNs to Kubernetes RBAC groups that grant permissions to the user."
  type        = map(list(string))

  # Example:
  # {
  #    "arn:aws:iam::ACCOUNT_ID:user/admin-user" = ["system:masters"]
  # }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to use. Refer to EKS docs for list of available versions (https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html)."
  type        = string
  default     = "1.14"
}

variable "endpoint_public_access" {
  description = "Whether or not to enable public API endpoints which allow access to the Kubernetes API from outside of the VPC."
  type        = bool
  default     = true
}
