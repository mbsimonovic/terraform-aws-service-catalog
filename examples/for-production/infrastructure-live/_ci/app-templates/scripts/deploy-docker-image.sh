#!/bin/bash
#
# Script used by github to trigger application deployments via the infrastructure-deployer CLI utility.
# This will use the terraform-applier container in the Gruntwork Pipelines solution to make a new commit to the main
# branch of the infrastructure-live repository to deploy the application using the newly built image.
#
# Required positional arguments, in order:
# - REGION : The AWS Region where the ECS Deploy Runner exists.
# - DOCKER_TAG : The tag to use when tagging the docker image that is built.
# - APP_DEPLOY_PATH : The relative path from the root of the infrastructure live repository to the terragrunt module for
#                     deploying this application.
# - APP_IMAGE_TAG_VARNAME : The name of the variable used to configure the docker image tag to deploy in the terragrunt
#                           module referenced by APP_DEPLOY_PATH.
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

# Invoke the ECS deploy runner using infrastructure-deployer to commit an update to the terragrunt configuration to
# deploy the newly built image. This commit will trigger the infrastructure CI/CD workflow to deploy the image.
function deploy_docker_image {
  local -r region="$1"
  local -r docker_tag="$2"
  local -r deploy_path="$3"
  local -r image_tag_varname="$4"

  local assume_role_exports
  assume_role_exports="$(assume_autodeploy_role)"

  local -a update_args=(--aws-region "$region" --)
  update_args+=(terraform-applier terraform-update-variable)
  update_args+=(--git-branch-name "$DEFAULT_INFRA_LIVE_BRANCH")
  update_args+=(--vars-path "$deploy_path/terragrunt.hcl")
  update_args+=(--name "$image_tag_varname" --value "\"$docker_tag\"")
  update_args+=(--skip-ci-flag "")
  (eval "$assume_role_exports" && infrastructure-deployer "${update_args[@]}")
}

function run {
  local -r region="$1"
  local -r docker_tag="$2"
  local -r app_deploy_path="$3"
  local -r app_image_tag_varname="$4"

  deploy_docker_image "$region" "$docker_tag" "$app_deploy_path" "$app_image_tag_varname"
}

run "$@"
