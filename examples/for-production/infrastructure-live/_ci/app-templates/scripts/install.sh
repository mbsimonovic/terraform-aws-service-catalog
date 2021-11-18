#!/bin/bash
#
# Script used by github to install the necessary helpers for the CI/CD pipeline
#
# Required environment variables:
# - GRUNTWORK_INSTALLER_VERSION : The version of the gruntwork-installer helper utility used to install scripts from the
#                                 Gruntwork IaC Library.
# - MODULE_CI_VERSION : The version of the terraform-aws-ci repository to use when installing the terraform helpers and
#                       infrastructure-deployer CLI.
# - MODULE_SECURITY_VERSION : The version of the terraform-aws-security repository to use when installing the aws-auth utility.
#

set -e

function run {
  local -r gruntwork_installer_version="$1"
  local -r module_ci_version="$2"
  local -r module_security_version="$3"

  curl -Ls https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh \
    | bash /dev/stdin --version "$gruntwork_installer_version"
  gruntwork-install --repo "https://github.com/gruntwork-io/terraform-aws-ci" \
    --binary-name "infrastructure-deployer" \
    --tag "$module_ci_version"
  gruntwork-install --repo "https://github.com/gruntwork-io/terraform-aws-security" \
    --module-name "aws-auth" \
    --tag "$module_security_version"
}

run "${GRUNTWORK_INSTALLER_VERSION}" "${MODULE_CI_VERSION}" "${MODULE_SECURITY_VERSION}"
