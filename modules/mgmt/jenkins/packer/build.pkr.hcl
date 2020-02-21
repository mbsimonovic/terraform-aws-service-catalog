build {
  sources = ["source.amazon-ebs.ubuntu_ami"]

  provisioner "shell" {
    inline = [
<<EOF
echo "Sleeping for 30 seconds to ensure apt-get is usable"
sleep 30

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install jq curl

curl -Ls https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh | bash /dev/stdin --version fixes

jenkins_version="${var.jenkins_version}"
module_security_version="${var.module_security_version}"
module_aws_monitoring_version="${var.module_aws_monitoring_version}"
module_stateful_server_version="${var.module_stateful_server_version}"
module_ci_version="${var.module_ci_version}"
kubergrunt_version="${var.kubergrunt_version}"
bash_commons_version="${var.bash_commons_version}"
terraform_version="${var.terraform_version}"
terragrunt_version="${var.terragrunt_version}"
kubectl_version="${var.kubectl_version}"
helm_version="${var.helm_version}"
packer_version="${var.packer_version}"
docker_version="${var.docker_version}"

version_args=()

if [[ -n "jenkins_version" ]]; then
  version_args+=("--module-param" "jenkins-version=$jenkins_version")
fi

if [[ -n "module_security_version" ]]; then
  version_args+=("--module-param" "module-security-version=$module_security_version")
fi

if [[ -n "module_aws_monitoring_version" ]]; then
  version_args+=("--module-param" "module-aws-monitoring-version=$module_aws_monitoring_version")
fi

if [[ -n "module_stateful_server_version" ]]; then
  version_args+=("--module-param" "module-stateful-server-version=$module_stateful_server_version")
fi

if [[ -n "module_ci_version" ]]; then
  version_args+=("--module-param" "module-ci-version=$module_ci_version")
fi

if [[ -n "kubergrunt_version" ]]; then
  version_args+=("--module-param" "kubergrunt-version=$kubergrunt_version")
fi

if [[ -n "bash_commons_version" ]]; then
  version_args+=("--module-param" "bash-commons-version=$bash_commons_version")
fi

if [[ -n "terraform_version" ]]; then
  version_args+=("--module-param" "terraform-version=$terraform_version")
fi

if [[ -n "terragrunt_version" ]]; then
  version_args+=("--module-param" "terragrunt-version=$terragrunt_version")
fi

if [[ -n "kubectl_version" ]]; then
  version_args+=("--module-param" "kubectl-version=$kubectl_version")
fi

if [[ -n "helm_version" ]]; then
  version_args+=("--module-param" "helm-version=$helm_version")
fi

if [[ -n "packer_version" ]]; then
  version_args+=("--module-param" "packer-version=$packer_version")
fi

if [[ -n "docker_version" ]]; then
  version_args+=("--module-param" "docker-version=$docker_version")
fi

gruntwork-install \
  --module-name mgmt/jenkins \
  --repo https://github.com/gruntwork-io/aws-service-catalog \
  --tag '${var.aws_service_catalog_ref}' \
  --module-param enable-ssh-grunt='${var.enable_ssh_grunt}' \
  --module-param enable-cloudwatch-metrics='${var.enable_cloudwatch_metrics}' \
  --module-param enable-cloudwatch-log-aggregation='${var.enable_cloudwatch_log_aggregation}' \
  "${version_ars[@]}"
EOF
    ]

    # We need to pass a GitHub personal access token to gruntwork-install to be able to access private GitHub repos
    environment_vars = [
      "GITHUB_OAUTH_TOKEN=${var.github_auth_token}"
    ]

    # Not yet supported: https://github.com/hashicorp/packer/issues/8783
    # pause_before = 30
  }
}