# Common variables for all AWS accounts.
locals {
  # ----------------------------------------------------------------------------------------------------------------
  # ACCOUNT IDS AND CONVENIENCE LOCALS
  # ----------------------------------------------------------------------------------------------------------------

  # Centrally define all the AWS account IDs. We use JSON so that it can be readily parsed outside of Terraform.
  accounts = jsondecode(file("accounts.json"))

  # Define a default region to use when operating on resources that are not contained within a specific region.
  default_region = "us-west-2"

  # A prefix used for naming resources.
  name_prefix = "gruntwork"

  # All accounts use the ECR repo in the shared account for the ecs-deploy-runner docker image.
  deploy_runner_ecr_uri             = "${local.accounts.shared}.dkr.ecr.${local.default_region}.amazonaws.com/ecs-deploy-runner"
  deploy_runner_container_image_tag = "v0.35.1"

  # All accounts use the ECR repo in the shared account for the Kaniko docker image.
  kaniko_ecr_uri             = "${local.accounts.shared}.dkr.ecr.${local.default_region}.amazonaws.com/kaniko"
  kaniko_container_image_tag = "v0.35.1"

  # The infastructure-live repository on which the deploy runner operates.
  infra_live_repo_https = "https://github.com/gruntwork-io/infrastructure-live"
  infra_live_repo_ssh   = "git@github.com:gruntwork-io/infrastructure-live.git"

  # These repos will be allowed for plan and apply operations in the CI/CD pipeline in addition to the value
  # provided in infra_live_repo_https
  additional_plan_and_apply_repos = [
    "git@github.com:gruntwork-clients/infrastructure-live-gruntwork.git",
  ]

  # The name of the S3 bucket in the Logs account where AWS Config will report its findings.
  config_s3_bucket_name = "gruntwork-config-logs"

  # The name of the S3 bucket in the Logs account where AWS CloudTrail will report its findings.
  cloudtrail_s3_bucket_name = "gruntwork-cloudtrail-logs"

  # IAM configurations for cross account ssh-grunt setup.
  ssh_grunt_users_group      = "ssh-grunt-users"
  ssh_grunt_sudo_users_group = "ssh-grunt-sudo-users"
  allow_ssh_grunt_role       = "arn:aws:iam::${local.accounts.security}:role/allow-ssh-grunt-access-from-other-accounts"

  # -------------------------------------------------------------------------------------------------------------------
  # COMMON NETWORK CONFIGURATION DATA
  # -------------------------------------------------------------------------------------------------------------------

  # Map of account name to VPC CIDR blocks to use for the mgmt VPC.
  mgmt_vpc_cidrs = {
    dev      = "172.31.80.0/20"
    logs     = "172.31.80.0/20"
    prod     = "172.31.80.0/20"
    security = "172.31.80.0/20"
    shared   = "172.31.80.0/20"
    stage    = "172.31.80.0/20"
  }

  # Map of account name to VPC CIDR blocks to use for the app VPC.
  app_vpc_cidrs = {
    dev   = "10.4.0.0/16"
    prod  = "10.2.0.0/16"
    stage = "10.0.0.0/16"
  }

  # List of known static CIDR blocks for the organization. Administrative access (e.g., VPN, SSH,
  # etc) will be limited to these source CIDRs.
  ip_allow_list = [
    "0.0.0.0/0",
  ]

  # Information used to generate the CA certificate used by OpenVPN in each account
  ca_cert_fields = {
    ca_country  = "US"
    ca_email    = "support@gruntwork.io"
    ca_locality = "Phoenix"
    ca_org      = "Gruntwork"
    ca_org_unit = "IT"
    ca_state    = "AZ"
  }

  # Centrally define the internal services domain name configured by the route53-private module
  internal_services_domain_name = "gruntwork.aws"
}
