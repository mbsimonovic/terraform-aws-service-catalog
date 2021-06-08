#!/bin/bash
# Build script for building Docker Container Images via the Gruntwork ECS deploy runner. Under the hood this
# script will invoke the docker-image-builder container of the ECS deploy runner (via the infrastructure-deployer CLI)
# that will invoke Kaniko to build the images.
#
# This script is intended to be run on a CI server that has the necessary credentials to invoke the ECS Deploy Runner in
# the Shared Services AWS account.
#
# This is the build script for the Deploy Runner Docker image. You can view the Dockerfile at the following URL:
# https://github.com/gruntwork-io/terraform-aws-ci/blob/v0.36.0/modules/ecs-deploy-runner/docker/deploy-runner

set -e

readonly DOCKERFILE_REPO="https://github.com/gruntwork-io/terraform-aws-ci.git"
readonly DOCKERFILE_REPO_REF="v0.36.0"
readonly DOCKERFILE_CONTEXT_PATH="modules/ecs-deploy-runner/docker/deploy-runner"
readonly DEPLOY_RUNNER_REGION="us-west-2"
readonly ECR_REPO_REGION="us-west-2"
readonly ECR_REPO_NAME="ecs-deploy-runner"

# The account IDs where the AMI should be shared.
git_repo_root="$(git rev-parse --show-toplevel)"

function run {
  # Validate that the AMI is being built in the Shared Services account.
  local account_id
  account_id="$(aws sts get-caller-identity --query 'Account' --output text)"
  shared_account_id="$(jq -r '.shared' "$git_repo_root/accounts.json")"
  if [[ "$account_id" != "$shared_account_id" ]]; then
    >&2 echo "Not authenticated to the correct account. Expected: $shared_account_id ; Actual: $account_id"
    exit 1
  fi

  local -r ecr_repo_url="$shared_account_id"'.dkr.ecr.'"$ECR_REPO_REGION"'.amazonaws.com/'"$ECR_REPO_NAME"

  # Build the Container Image using the ECS deploy runner by invoking the infrastructure-deployer CLI.
  # NOTE: The ECS deploy runner will inject the following parameters automatically:
  # - "--idempotent 'true'"
  infrastructure-deployer --aws-region "$DEPLOY_RUNNER_REGION" -- docker-image-builder build-docker-image \
    --repo "$DOCKERFILE_REPO" \
    --ref "$DOCKERFILE_REPO_REF" \
    --context-path "$DOCKERFILE_CONTEXT_PATH" \
    --build-arg 'GITHUB_OAUTH_TOKEN' \
    --docker-image-tag "$ecr_repo_url:$DOCKERFILE_REPO_REF"
}

# Run the main function if this script is called directly, instead of being sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run "$@"
fi