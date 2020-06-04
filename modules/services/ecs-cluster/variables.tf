# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "aws_account_id" {
  description = "The ID of the AWS Account in which to create resources."
  type        = string
}

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "cluster_min_size" {
  description = "The minimum number of instances to run in the ECS cluster"
  type        = number
}

variable "cluster_max_size" {
  description = "The maxiumum number of instances to run in the ECS cluster"
  type        = number
}

variable "cluster_instance_type" {
  description = "The type of instances to run in the ECS cluster (e.g. t2.medium)"
  type        = string
}

variable "cluster_instance_ami" {
  description = "The AMI to run on each instance in the ECS cluster. You can build the AMI using the Packer template under packer/build.json."
  type        = string
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC in which to run the ECS cluster (e.g. stage, prod)"
  type        = string
}

variable "terraform_state_aws_region" {
  description = "The AWS region of the S3 bucket used to store Terraform remote state"
  type        = string
}

variable "terraform_state_s3_bucket" {
  description = "The name of the S3 bucket used to store Terraform remote state"
  type        = string
}

variable "allow_requests_from_public_alb" {
  description = "Set to true to allow inbound requests to this ECS cluster from the public ALB (if you're using one)"
  type        = bool
  default     = false
}

{{- if .IncludeInternalAlb }}

variable "allow_requests_from_internal_alb" {
  description = "Set to true to allow inbound requests to this ECS cluster from the internal ALB (if you're using one)"
  type        = bool
  default     = false
}
{{- end }}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "allow_ssh" {
  description = "Set to true to allow SSH access to this ECS cluster from the {{ if .UsingOpenVpn }}OpenVPN server{{ else }}bastion host{{ end }}."
  type        = bool
  default     = true
}

{{- if or (eq .DockerAuthType "docker-hub") (eq .DockerAuthType "docker-gitlab") (eq .DockerAuthType "docker-other") }}

# For info on how ECS authenticates to private Docker registries, see:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html
variable "docker_repo_auth" {
  description = "The Docker auth value, encrypted with a KMS master key, that can be used to download your private images from Docker Hub. This is not your password! To get the auth value, run 'docker login', enter a machine user's credentials, and when you're done, copy the 'auth' value from ~/.docker/config.json. To encrypt the value with KMS, use gruntkms with a master key. Note that these instances will use gruntkms to decrypt the data, so the IAM role of these instances must be granted permission to access the KMS master key you use to encrypt this data!"
  type        = string
}
{{- end }}

{{- if or (eq .DockerAuthType "docker-gitlab") }}

variable "docker_registry_url" {
  description = "The URL of your Docker Registry"
  type        = string
}
{{- end }}

{{- if or (eq .DockerAuthType "docker-hub") (eq .DockerAuthType "docker-other") }}

# For info on how ECS authenticates to private Docker registries, see:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html
variable "docker_repo_email" {
  description = "The Docker email address that can be used used to download your private images from Docker Hub."
  type        = string
}
{{- end }}

{{- if .IamUsersDefinedInSeparateAccount }}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
}
{{- end }}

{{- if .InstallCloudWatchMonitoring }}

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a CPU utilization percentage above this threshold"
  type        = number
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage"
  type        = number
}

variable "high_memory_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a memory utilization percentage above this threshold"
  type        = number
}

variable "high_memory_utilization_period" {
  description = "The period, in seconds, over which to measure the memory utilization percentage"
  type        = number
}

variable "high_disk_utilization_threshold" {
  description = "Trigger an alarm if the EC2 instances in the ECS Cluster have a disk utilization percentage above this threshold"
  type        = number
}

variable "high_disk_utilization_period" {
  description = "The period, in seconds, over which to measure the disk utilization percentage"
  type        = number
}
{{- end }}

{{- if .RunDataDogEcsTask }}

variable "data_dog_api_key_encrypted" {
  description = "Your DataDog API Key, encrypted with KMS"
  type        = string
}
{{- end }}

variable "terraform_state_kms_master_key" {
  description = "Path base name of the kms master key to use. This should reflect what you have in your infrastructure-live folder."
  type = string
  default = "kms-master-key"
}

