#!/usr/bin/env bash
# Install Jenkins and Gruntwork dependencies on a Linux server

set -e

readonly JENKINS_USER="jenkins"


# Gruntwork module versions
# renovate.json auto-update: terraform-aws-ci
readonly DEFAULT_MODULE_CI_VERSION="v0.29.8"

# Build tooling
# renovate.json auto-update: kubergrunt
readonly DEFAULT_KUBERGRUNT_VERSION="v0.6.9"
# renovate.json auto-update: terragrunt
readonly DEFAULT_TERRAGRUNT_VERSION="v0.27.1"

# renovate.json auto-update-github-releases: jenkinsci/jenkins
readonly DEFAULT_JENKINS_VERSION="2.235.5"
# renovate.json auto-update-github-releases: hashicorp/terraform
readonly DEFAULT_TERRAFORM_VERSION="0.12.21"
# We intentionally do NOT auto update K8S, as it should be tied to EKS versions, and our support for them in
# terraform-aws-eks, both of which lag behind open source K8S
readonly DEFAULT_KUBECTL_VERSION="v1.17.3"
# renovate.json auto-update-github-releases: helm/helm
readonly DEFAULT_HELM_VERSION="v3.4.1"
# renovate.json auto-update-github-releases: hashicorp/packer
readonly DEFAULT_PACKER_VERSION="1.6.5"
# renovate.json auto-update-docker-ubuntu
readonly DEFAULT_DOCKER_VERSION="18.06.1~ce~3-0~ubuntu"

# You can set the version of the build tooling to this value to skip installing it
readonly SKIP_INSTALL_VERSION="NONE"

function include_ec2_baseline {
  if [[ "$1" ]]; then
    ec2_baseline_version_branch="--branch $1"
  fi
  if [[ "$2" ]]; then
    ec2_baseline_version_tag="--tag $2"
  fi
  if [[ "$ec2_baseline_version_branch" == "" && "$ec2_baseline_version_tag" == "" ]]; then
    echo "ERROR: no version was provided for ec2-baseline module."
    exit 1
  fi

  gruntwork-install \
    --module-name base/ec2-baseline \
    --repo https://github.com/gruntwork-io/terraform-aws-service-catalog \
    ${ec2_baseline_version_branch} \
    ${ec2_baseline_version_tag}

  # Include common defaults and functions from the ec2-baseline install script
  # See: https://github.com/gruntwork-io/terraform-aws-service-catalog/blob/master/modules/base/ec2-baseline
  readonly EC2_BASELINE_RELATIVE_PATH="../../base/ec2-baseline"
  readonly EC2_BASELINE_PATH="$(dirname $(realpath $0))/${EC2_BASELINE_RELATIVE_PATH}"
  if [[ ! -f "${EC2_BASELINE_PATH}/install.sh" ]]; then
    echo "ERROR: $EC2_BASELINE_PATH/install.sh not found."
    exit 1
  fi

  source $EC2_BASELINE_PATH/install.sh
}

function install_ci_packages {
  local -r module_ci_version="$1"
  local -r jenkins_version="$2"

  echo "Installing Gruntwork CI Modules"

  gruntwork-install --module-name 'install-jenkins' --repo 'https://github.com/gruntwork-io/terraform-aws-ci' --tag "$module_ci_version" --module-param "version=$jenkins_version"
  gruntwork-install --module-name 'build-helpers' --repo 'https://github.com/gruntwork-io/terraform-aws-ci' --tag "$module_ci_version"
  gruntwork-install --module-name 'git-helpers' --repo 'https://github.com/gruntwork-io/terraform-aws-ci' --tag "$module_ci_version"
  gruntwork-install --module-name 'terraform-helpers' --repo 'https://github.com/gruntwork-io/terraform-aws-ci' --tag "$module_ci_version"
}

function install_kubergrunt {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Kubergrunt version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Kubergrunt"
  gruntwork-install --binary-name "kubergrunt" --repo "https://github.com/gruntwork-io/kubergrunt" --tag "$version"
  sudo chmod 755 /usr/local/bin/kubergrunt
}

function install_terraform {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Terraform version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Terraform $version"
  wget "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
  unzip "terraform_${version}_linux_amd64.zip"
  sudo cp terraform /usr/local/bin/terraform
  sudo chmod a+x /usr/local/bin/terraform
}

function install_terragrunt {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Terragrunt version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Terragrunt $version"
  wget "https://github.com/gruntwork-io/terragrunt/releases/download/$version/terragrunt_linux_amd64"
  sudo cp terragrunt_linux_amd64 /usr/local/bin/terragrunt
  sudo chmod a+x /usr/local/bin/terragrunt
}

function install_packer {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Packer version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Packer $version"
  wget "https://releases.hashicorp.com/packer/${version}/packer_${version}_linux_amd64.zip"
  unzip "packer_${version}_linux_amd64.zip"
  sudo cp packer /usr/local/bin/packer
  sudo chmod a+x /usr/local/bin/packer
}

function install_kubectl {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "kubectl version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Kubectl $version"
  wget "https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl"
  sudo mv kubectl /usr/local/bin/kubectl
  sudo chmod a+x /usr/local/bin/kubectl
}

function install_helm {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Helm version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Helm $version"
  wget "https://get.helm.sh/helm-${version}-linux-amd64.tar.gz"
  tar -xvf "helm-${version}-linux-amd64.tar.gz"
  sudo mv linux-amd64/helm /usr/local/bin/helm
  sudo chmod a+x /usr/local/bin/helm

  echo "Initialize stable repository"
  helm repo add stable https://charts.helm.sh/stable

  echo "Cleaning up temporary files"
  rm -rf linux-amd64
  rm "helm-${version}-linux-amd64.tar.gz"
}

# Based on: https://docs.docker.com/engine/installation/linux/ubuntu/#install-using-the-repository
function install_docker {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Docker version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Docker $version"

  sudo apt-get install -y linux-image-extra-virtual
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce="$version"

  # This allows us to run Docker without sudo: http://askubuntu.com/a/477554
  echo "Adding user $JENKINS_USER to Docker group"
  sudo gpasswd -a "$JENKINS_USER" docker
}

function install_git {
  echo "Installing Git"
  sudo apt-get install -y git
}

function install_build_dependencies {
  local -r terraform_version="$1"
  local -r terragrunt_version="$2"
  local -r kubectl_version="$3"
  local -r helm_version="$4"
  local -r packer_version="$5"
  local -r docker_version="$6"

  install_terraform "$terraform_version"
  install_terragrunt "$terragrunt_version"
  install_packer "$packer_version"
  install_kubectl "$kubectl_version"
  install_helm "$helm_version"
  install_docker "$docker_version"
  install_git
}

function install_modules_for_ci {
  local -r jenkins_version="$1"
  local -r module_stateful_server_version="$2"
  local -r module_ci_version="$3"
  local -r kubergrunt_version="$4"

  install_aws_cli
  install_stateful_server_packages "$module_stateful_server_version"
  install_ci_packages "$module_ci_version" "$jenkins_version"
  install_kubergrunt "$kubergrunt_version"
}

function install_jenkins {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local jenkins_version="${jenkins_version:-$DEFAULT_JENKINS_VERSION}"
  local module_security_version="${module_security_version:-$DEFAULT_MODULE_SECURITY_VERSION}"
  local module_aws_monitoring_version="${module_aws_monitoring_version:-$DEFAULT_MODULE_AWS_MONITORING_VERSION}"
  local module_stateful_server_version="${module_stateful_server_version:-$DEFAULT_MODULE_STATEFUL_SERVER_VERSION}"
  local module_ci_version="${module_ci_version:-$DEFAULT_MODULE_CI_VERSION}"
  local kubergrunt_version="${kubergrunt_version:-$DEFAULT_KUBERGRUNT_VERSION}"
  local bash_commons_version="${bash_commons_version:-$DEFAULT_BASH_COMMONS_VERSION}"
  local terraform_version="${terraform_version:-$DEFAULT_TERRAFORM_VERSION}"
  local terragrunt_version="${terragrunt_version:-$DEFAULT_TERRAGRUNT_VERSION}"
  local kubectl_version="${kubectl_version:-$DEFAULT_KUBECTL_VERSION}"
  local helm_version="${helm_version:-$DEFAULT_HELM_VERSION}"
  local packer_version="${packer_version:-$DEFAULT_PACKER_VERSION}"
  local docker_version="${docker_version:-$DEFAULT_DOCKER_VERSION}"
  local enable_ssh_grunt="${enable_ssh_grunt:-$DEFAULT_ENABLE_SSH_GRUNT}"
  local enable_cloudwatch_metrics="${enable_cloudwatch_metrics:-$DEFAULT_ENABLE_CLOUDWATCH_METRICS}"
  local enable_cloudwatch_log_aggregation="${enable_cloudwatch_log_aggregation:-$DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION}"

  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
      --jenkins-version)
        assert_not_empty "$key" "$2"
        jenkins_version="$2"
        shift
        ;;
      --module-security-version)
        assert_not_empty "$key" "$2"
        module_security_version="$2"
        shift
        ;;
      --terraform-aws-monitoring-version)
        assert_not_empty "$key" "$2"
        module_aws_monitoring_version="$2"
        shift
        ;;
      --module-stateful-server-version)
        assert_not_empty "$key" "$2"
        module_stateful_server_version="$2"
        shift
        ;;
      --module-ci-version)
        assert_not_empty "$key" "$2"
        module_ci_version="$2"
        shift
        ;;
      --kubergrunt-version)
        assert_not_empty "$key" "$2"
        kubergrunt_version="$2"
        shift
        ;;
      --bash-commons-version)
        assert_not_empty "$key" "$2"
        bash_commons_version="$2"
        shift
        ;;
      --terraform-version)
        assert_not_empty "$key" "$2"
        terraform_version="$2"
        shift
        ;;
      --terragrunt-version)
        assert_not_empty "$key" "$2"
        terragrunt_version="$2"
        shift
        ;;
      --kubectl-version)
        assert_not_empty "$key" "$2"
        kubectl_version="$2"
        shift
        ;;
      --helm-version)
        assert_not_empty "$key" "$2"
        helm_version="$2"
        shift
        ;;
      --packer-version)
        assert_not_empty "$key" "$2"
        packer_version="$2"
        shift
        ;;
      --docker-version)
        assert_not_empty "$key" "$2"
        docker_version="$2"
        shift
        ;;
      --enable-ssh-grunt)
        enable_ssh_grunt="$2"
        shift
        ;;
      --enable-cloudwatch-metrics)
        enable_cloudwatch_metrics="$2"
        shift
        ;;
      --enable-cloudwatch-log-aggregation)
        enable_cloudwatch_log_aggregation="$2"
        shift
        ;;
      *)
        echo "ERROR: Unrecognized argument: $key"
        exit 1
        ;;
    esac

    shift
  done

  assert_env_var_not_empty "GITHUB_OAUTH_TOKEN"

  install_gruntwork_modules \
    "$bash_commons_version" \
    "$module_security_version" \
    "$module_aws_monitoring_version" \
    "$enable_ssh_grunt" \
    "$enable_cloudwatch_metrics" \
    "$enable_cloudwatch_log_aggregation"

  install_modules_for_ci \
    "$jenkins_version" \
    "$module_stateful_server_version" \
    "$module_ci_version" \
    "$kubergrunt_version" \

  install_build_dependencies \
    "$terraform_version" \
    "$terragrunt_version" \
    "$kubectl_version" \
    "$helm_version" \
    "$packer_version" \
    "$docker_version"

  install_user_data \
    "${EC2_BASELINE_PATH}/user-data-common.sh"
}

# Determine which version of the EC2 baseline module to install.
# Prioritize an environment variable set by Packer, and fall back to the value
# set by the gruntwork-install script in GRUNTWORK_INSTALL_BRANCH or GRUNTWORK_INSTALL_TAG
# If branch and tag are both set, gruntwork-install prefers branch
module_ec2_baseline_branch="${module_ec2_baseline_branch:-$GRUNTWORK_INSTALL_BRANCH}"
module_ec2_baseline_tag="${module_ec2_baseline_version:-$GRUNTWORK_INSTALL_TAG}"
include_ec2_baseline "$module_ec2_baseline_branch" "$module_ec2_baseline_tag"

install_jenkins "$@"
