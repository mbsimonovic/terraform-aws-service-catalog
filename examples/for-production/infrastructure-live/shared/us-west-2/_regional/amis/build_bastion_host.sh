#!/bin/bash
# Build script for building EC2 Amazon Machine Images (AMIs) via the Gruntwork ECS deploy runner. Under the hood this
# script will invoke the ami-builder container of the ECS deploy runner (via the infrastructure-deployer CLI) that will
# invoke Packer against the specified Packer template to build the AMI.
#
# This script is intended to be run on a CI server that has the necessary credentials to invoke the ECS Deploy Runner in
# the Shared Services AWS account.
#
# This is the build script for the Bastion Host AMI. You can view the packer template at the following URL:
# https://github.com/gruntwork-io/aws-sample-app/blob/v0.0.4/modules/mgmt/bastion-host/bastion-host-ubuntu.pkr.hcl
#
# Pass in the --run-local flag to build the image on the local machine, without going through the ECS Deploy Runner.

set -e

readonly PACKER_TEMPLATE_REPO="https://github.com/gruntwork-io/aws-sample-app.git//modules/mgmt/bastion-host/bastion-host-ubuntu.pkr.hcl"
readonly PACKER_TEMPLATE_REPO_REF="v0.0.4"
readonly SERVICE_CATALOG_REF="v0.62.0"
readonly DEPLOY_RUNNER_REGION="us-west-2"
readonly REGION="us-west-2"

# The account IDs where the AMI should be shared.
git_repo_root="$(git rev-parse --show-toplevel)"
dev_account_id="$(jq -r '."dev"' "$git_repo_root/accounts.json")"
prod_account_id="$(jq -r '."prod"' "$git_repo_root/accounts.json")"
stage_account_id="$(jq -r '."stage"' "$git_repo_root/accounts.json")"
ami_account_ids="[\"$dev_account_id\",\"$prod_account_id\",\"$stage_account_id\"]"

function run {
  local run_local="false"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --run-local)
        run_local="true"
        ;;
    esac

    shift
  done

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
  args=( \
    --packer-template-path "git::$PACKER_TEMPLATE_REPO?ref=$PACKER_TEMPLATE_REPO_REF" \
    --var service_catalog_ref="$SERVICE_CATALOG_REF" \
    --var version_tag="$PACKER_TEMPLATE_REPO_REF" \
    --var aws_region="$REGION" \
    --var ami_users="$ami_account_ids" \
    --var vpc_filter_key="tag:Name" \
    --var vpc_filter_value="mgmt" \
    --var vpc_subnet_filter_key="tag:Name" \
    --var encrypt_boot=true \
    --var encrypt_kms_key_id="arn:aws:kms:us-east-1:234567890123:alias/ExampleAMIEncryptionKMSKeyArn"
  )

  if [[ "$run_local" == 'true' ]]; then
    # When running locally, the packer instance needs to be deployed in the public subnet so it is accessible.
    args+=( \
      --var vpc_subnet_filter_value="mgmt-public-1"
    )

    build-packer-artifact "${args[@]}"
  else
    # When running from ECS Deploy Runner, the packer instance needs to be deployed in the private to protect it.
    args+=( \
      --var vpc_subnet_filter_value="mgmt-private-1" \
      --var associate_public_ip_address="false" \
      --var ssh_interface="private_ip"
    )

    infrastructure-deployer --aws-region "$DEPLOY_RUNNER_REGION" -- ami-builder build-packer-artifact "${args[@]}"
  fi
}

# Run the main function if this script is called directly, instead of being sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run "$@"
fi