# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

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



variable "vpc_id" {
  description = "The ID of the VPC in which the ECS cluster should be launched"
  type        = string
}

variable "vpc_subnet_ids" {
  description = "The IDs of the subnets in which to deploy the ECS cluster instances"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the ECS cluster instances during boot. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax"
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "allow_requests_from_public_alb" {
  description = "Set to true to allow inbound requests to this ECS cluster from the public ALB (if you're using one)"
  type        = bool
  default     = false
}

variable "public_alb_sg_ids" {
  description = "The Security Group ID for the public ALB"
  type        = list(string)
  default     = []
}

variable "internal_alb_sg_ids" {
  description = "The Security Group ID for the internal ALB"
  type        = list(string)
  default     = []
}

variable "include_internal_alb" {
  description = "Set to true to if you want to put an internal application load balancer in front of the ECS cluster"
  type        = bool
  default     = false
}

variable "cluster_instance_keypair_name" {
  description = "The name of the Key Pair that can be used to SSH to each instance in the ECS cluster"
  type        = string
  default     = null
}

variable "docker_auth_type" {
  description = "The docker authentication strategy to use for pulling Docker images. MUST be one of: (docker-hub, docker-other, docker-gitlab)"
  type        = string
}

variable "run_data_dog_ecs_task" {
  description = "Set to true to run Datadog to monitor the ECS cluster"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to install Cloudwatch monitoring and alerts in the cluster"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to enable Cloudwatch log aggregation for the ECS cluster"
  type        = bool
  default     = false
}



# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables will be set to their default values if not passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "allow_requests_from_internal_alb" {
  description = "Set to true to allow inbound requests to this ECS cluster from the internal ALB. Only used if var.include_internal_alb is set to true"
  type        = bool
  default     = false
}

variable "tenancy" {
  description = "The tenancy of this server. Must be one of: default, dedicated, or host."
  type        = string
  default     = "default"
}

variable "allow_ssh" {
  description = "Set to true to allow SSH access to this ECS cluster from either the openvpn server or bastion-host, depending upon which you are using"
  type        = bool
  default     = true
}

variable "allow_ssh_from_cidr_blocks" {
  description = "The IP address ranges in CIDR format from which to allow incoming SSH requests to the ECS instances. Only used if var.allow_ssh is set to true"
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which to allow incoming SSH requests to the ECS instances. Only used if var.allow_ssh is set to true"
  type        = list(string)
  default     = []
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true"
  type        = bool
  default     = true
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true"
  type        = bool
  default     = true
}

# For info on how ECS authenticates to private Docker registries, see:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html
variable "docker_repo_auth" {
  description = "The Docker auth value, encrypted with a KMS master key, that can be used to download your private images from Docker Hub. This is not your password! To get the auth value, run 'docker login', enter a machine user's credentials, and when you're done, copy the 'auth' value from ~/.docker/config.json. To encrypt the value with KMS, use gruntkms with a master key. Note that these instances will use gruntkms to decrypt the data, so the IAM role of these instances must be granted permission to access the KMS master key you use to encrypt this data! Used if var.docker_auth_type is set to docker-hub, docker-gitlab or docker-other"
  type        = string
  default     = null
}

variable "docker_registry_url" {
  description = "The URL of your Docker Registry. Only used if var.docker_auth_type is set to docker-gitlab"
  type        = string
  default     = null
}


variable "docker_auth_type" {
  description = "The docker authentication strategy to use for pulling Docker images. MUST be one of: (docker-hub, docker-other, docker-gitlab)"
  type        = string
  default     = null
}

# For info on how ECS authenticates to private Docker registries, see:
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html
variable "docker_repo_email" {
  description = "The Docker email address that can be used used to download your private images from Docker Hub. Only used if var.docker_auth_type is set to docker-hub or docker-other"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# SSH GRUNT VARIABLES
# These variables optionally enable and configure access via ssh-grunt. See: https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt for more info.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the ECS nodes. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = null
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the ECS nodes with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = null
}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# CLUSTER VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_autoscaling" {
  description = "Set to true to enable autoscaling for the ECS cluster based on CPU utilization."
  type        = bool
  default     = true
}

variable "enable_cluster_access_ports" {
  description = "Specify a list of ECS Cluster ports which should be accessible from the security groups given in cluster_access_from_sgs"
  type        = list
  default     = []
}

variable "cluster_access_from_sgs" {
  description = "Specify a list of Security Groups that will have access to the ECS cluster. Only used if var.enable_cluster_access_ports is set to true"
  type        = list
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# DATADOG INTEGRATION
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_datadog_task" {
  description = "Set to true to run the DataDog agent as an ECS task on each EC2 instance in the ECS cluster."
  type        = bool
  default     = false
}

variable "datadog_task_arn" {
  description = "The ARN of the Datadog agent task definition"
  type        = string
  default     = null
}

variable "datadog_api_key_secret" {
  description = "The ARN of an AWS Secrets Manager secret containing your Datadog API Key"
  type        = string
  default     = null
}

variable "data_dog_api_key_encrypted" {
  description = "Your DataDog API Key, encrypted with KMS. Only required if var.run_data_dog_ecs_task is set to true"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH MONITORING VARIABLES
# These variables optionally configure Cloudwatch alarms to monitor resource usage in the ECS cluster and raise alerts when defined thresholds are exceeded 
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_ecs_cloudwatch_alarms" {
  description = "Set to true to enable several basic Cloudwatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn"
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications"
  type        = list(string)
  default     = []
}

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a CPU utilization percentage above this threshold. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

variable "high_memory_utilization_threshold" {
  description = "Trigger an alarm if the ECS Cluster has a memory utilization percentage above this threshold. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

variable "high_memory_utilization_period" {
  description = "The period, in seconds, over which to measure the memory utilization percentage. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

variable "high_disk_utilization_threshold" {
  description = "Trigger an alarm if the EC2 instances in the ECS Cluster have a disk utilization percentage above this threshold. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

variable "high_disk_utilization_period" {
  description = "The period, in seconds, over which to measure the disk utilization percentage. Only used if var.enable_cloudwatch_alarms is set to true"
  type        = number
}

