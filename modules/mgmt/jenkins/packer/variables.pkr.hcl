# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# Pass in a GitHub personal access token via env var to be able to access private GitHub repos
variable "github_auth_token" {}

# The Git ref (tag or branch) of the aws-service-catalog to use
variable "aws_service_catalog_ref" {}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# The region in which to build the AMI
variable "aws_region" {
  default = "us-east-1"
}

# Other AWS regions to copy the AMI to
variable "copy_to_regions" {
  default = []
}

# The version of Jenkins to install. Set to empty string to use the default version this module has been tested with.
variable "jenkins_version" {
  default = ""
}

# The version of module-security to install. Set to empty string to use the default version this module has been tested with.
variable "module_security_version" {
  default = ""
}

# The version of module-aws-monitoring to install. Set to empty string to use the default version this module has been tested with.
variable "module_aws_monitoring_version" {
  default = ""
}

# The version of module-server to install. Set to empty string to use the default version this module has been tested with.
variable "module_stateful_server_version" {
  default = ""
}

# The version of module-ci to install. Set to empty string to use the default version this module has been tested with.
variable "module_ci_version" {
  default = ""
}

# The version of kubergrunt to install. Set to empty string to use the default version this module has been tested with.
variable "kubergrunt_version" {
  default = ""
}

# The version of bash-commons to install. Set to empty string to use the default version this module has been tested with.
variable "bash_commons_version" {
  default = ""
}

# The version of Terraform to install. Set to empty string to use the default version this module has been tested with.
variable "terraform_version" {
  default = ""
}

# The version of Terragrunt to install. Set to empty string to use the default version this module has been tested with.
variable "terragrunt_version" {
  default = ""
}

# The version of Kubectl to install. Set to empty string to use the default version this module has been tested with.
variable "kubectl_version" {
  default = ""
}

# The version of Helm client to install. Set to empty string to use the default version this module has been tested with.
variable "helm_version" {
  default = ""
}

# The version of Packer to install. Set to empty string to use the default version this module has been tested with.
variable "packer_version" {
  default = ""
}

# The version of Docker to install. Set to empty string to use the default version this module has been tested with.
variable "docker_version" {
  default = ""
}

# Set to true to encrypt the root volume of the resulting AMI
variable "encrypt_boot" {
  default = "false"
}

# A list of AWS account IDs with which to share the resulting AMI
variable "ami_users" {
  default = []
}

# Set to true to install ssh-grunt so you can manage SSH access via IAM groups
variable "enable_ssh_grunt" {
  default = "true"
}

# Set to true to install utilities to send custom metrics (namely, memory and disk space usage) to CloudWatch
variable "enable_cloudwatch_metrics" {
  default = "true"
}

# Set to true to install utilities to send logs to CloudWatch
variable "enable_cloudwatch_log_aggregation" {
  default = "true"
}
