#!/bin/bash
#
# Script used by github to build docker images for the application via the infrastructure-deployer CLI utility.
#
# Required positional arguments, in order:
# - REGION : The AWS Region where the ECS Deploy Runner exists.
# - SHA : The commit SHA to use for building the docker image.
# - DOCKER_TAG : The tag to use when tagging the docker image that is built.
#
# Assumptions by script:
# - The script is run from a git repo corresponding to the application source code.
# - The application is packaged as a docker container.
#


set -e
set -o pipefail

# Locate the directory in which this script is located, and use that to determine where the constants are.
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_path/constants.sh"

# A function that uses aws-auth to assume the IAM role for invoking the ECS Deploy Runner.
function assume_autodeploy_role {
  local -r autodeploy_role_arn="arn:aws:iam::$SHARED_SERVICES_ACCOUNT_ID:role/allow-auto-deploy-from-other-accounts"
  aws-auth --role-arn "$autodeploy_role_arn" --role-duration-seconds 3600
}

# Invoke the ECS deploy runner using infrastructure-deployer to build and push the docker image for the application.
function build_docker_image {
  local -r region="$1"
  local -r sha="$2"
  local -r docker_tag="$3"

  local assume_role_exports
  assume_role_exports="$(assume_autodeploy_role)"

  local -a build_args=(--aws-region "$region" --)
  build_args+=(docker-image-builder build-docker-image)
  build_args+=(--repo "$REPO_HTTP")
  build_args+=(--sha "$sha")
  build_args+=(--context-path "$DOCKER_CONTEXT_PATH")
  build_args+=(--docker-image-tag "$DOCKER_REPO_URL:$docker_tag")
  (eval "$assume_role_exports" && infrastructure-deployer "${build_args[@]}")
}

build_docker_image "$@"
