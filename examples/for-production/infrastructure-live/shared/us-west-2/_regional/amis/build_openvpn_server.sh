#!/bin/bash
# Build script for building EC2 Amazon Machine Images (AMIs) via the Gruntwork ECS deploy runner. Under the hood this
# script will invoke the ami-builder container of the ECS deploy runner (via the infrastructure-deployer CLI) that will
# invoke Packer against the specified Packer template to build the AMI.
#
# This script is intended to be run on a CI server that has the necessary credentials to invoke the ECS Deploy Runner in
# the Shared Services AWS account.
#
# This is the build script for the OpenVPN Server AMI. You can view the packer template at the following URL:
# https://github.com/gruntwork-io/terraform-aws-service-catalog/blob/v0.44.2/modules/mgmt/openvpn-server/openvpn-server.json

set -e

readonly PACKER_TEMPLATE_REPO="https://github.com/gruntwork-io/terraform-aws-service-catalog.git//modules/mgmt/openvpn-server/openvpn-server.json"
readonly PACKER_TEMPLATE_REPO_REF="v0.44.2"
readonly SERVICE_CATALOG_REF="v0.44.2"
readonly DEPLOY_RUNNER_REGION="us-west-2"
readonly REGION="us-west-2"

# The account IDs where the AMI should be shared.
git_repo_root="$(git rev-parse --show-toplevel)"
dev_account_id="$(jq -r '.dev' "$git_repo_root/accounts.json")"
prod_account_id="$(jq -r '.prod' "$git_repo_root/accounts.json")"
stage_account_id="$(jq -r '.stage' "$git_repo_root/accounts.json")"
ami_account_ids="$dev_account_id,$prod_account_id,$stage_account_id"

function run {
  # Validate that the AMI is being built in the Shared Services account.
  local account_id
  account_id="$(aws sts get-caller-identity --query 'Account' --output text)"
  shared_account_id="$(jq -r '.shared' "$git_repo_root/accounts.json")"
  if [[ "$account_id" != "$shared_account_id" ]]; then
    >&2 echo "Not authenticated to the correct account. Expected: $shared_account_id ; Actual: $account_id"
    exit 1
  fi

  # Build the AMI using the ECS deploy runner by invoking the infrastructure-deployer CLI.
  # NOTE: The ECS deploy runner will inject the following parameters automatically:
  # - "--idempotent 'true'"
  # - "--ssh-key-secrets-manager-arn $ARN"
  # - "--github-token-secrets-manager-arn" (When using GitHub as a VCS.)
  # - "--gitlab-token-secrets-manager-arn" (When using GitLab as a VCS.)
  # - "--bitbucket-token-secrets-manager-arn" (When using Bitbucket as a VCS.)
  # - "--bitbucket-username" (When using Bitbucket as a VCS.)
  infrastructure-deployer --aws-region "$DEPLOY_RUNNER_REGION" -- ami-builder build-packer-artifact \
    --packer-template-path "git::$PACKER_TEMPLATE_REPO?ref=$PACKER_TEMPLATE_REPO_REF" \
    --var service_catalog_ref="$SERVICE_CATALOG_REF" \
    --var version_tag="$PACKER_TEMPLATE_REPO_REF" \
    --var aws_region="$REGION" \
    --var ami_users="$ami_account_ids" \
    --var encrypt_boot=true \
    --var encrypt_kms_key_id="arn:aws:kms:us-east-1:234567890123:alias/ExampleAMIEncryptionKMSKeyArn"
}

# Run the main function if this script is called directly, instead of being sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run "$@"
fi