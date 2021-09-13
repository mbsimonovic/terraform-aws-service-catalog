#!/bin/bash
#
# Script used by circleci to trigger infrastructure deployments via the infrastructure-deployer CLI utility on
# live infrastructure config.
#
# Required positional arguments, in order:
# - SOURCE_REF : The starting point for identifying all the changes. The diff between SOURCE_REF and REF will be
#                evaluated to determine all the changed files.
# - REF : The end point for identifying all the changes. The diff between SOURCE_REF and REF will be evaluated to
#         determine all the changed files.
# - COMMAND : The command to run. Should be one of plan or apply.
#
# Assumptions by script:
# - The script is run from a git repo corresponding to live infrastructure configurations (e.g., terragrunt modules).
# - There exists a json file named accounts.json at the root of the repo that maps AWS account names to AWS account IDs.
# - The first folder in the repository corresponds to AWS account names, and the accounts.json file contains an entry
#   for each folder.
#

set -e
set -o pipefail

# Locate the directory in which this script is located, and use that to determine where the helper functions are.
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_path/helpers.sh"

# Function that routes updates to various folders to specific CI/CD actions to take. For example, we ignore changes to
# to the ecs-deploy-runner folder as they contain infrastructure to manage the ECS deploy runner, and currently the
# deploy runner can't manage itself.
function route {
  local -r updated_folder="$1"

  # Add to this condition if you have other modules you do not want to manage with ECS deploy runner.
  if [[ "$updated_folder" == "." ]]; then
    echo "WARNING: A configuration in the repository root has changed. Because this could potentially impact many configurations, an operator must run a plan-all or apply-all manually in each account."
  elif [[ "$updated_folder" =~ "^.+/ecs-deploy-runner(/.+)?$" ]]; then
    echo "No action defined for changes to $updated_folder."
  else
    invoke_infrastructure_deployer "$@"
  fi
}

# Function that invokes the ECS Deploy Runner using the infrastructure-deployer CLI. This will also make sure to assume
# the correct IAM role based on the deploy path.
# ASSUMPTION: The infrastructure-live repository (this repo) is organized in a way such that the first folder is the AWS
# Account name (as it relates to the accounts.json file).
function invoke_infrastructure_deployer {
  local -r updated_folder="$1"
  local -r ref="$2"
  local -r command="$3"
  local -r command_args="$4"
  local -r source_ref="$5"

  local repo_url
  repo_url="$(get_git_origin_url)"

  local -r ecs_deploy_runner_region='us-west-2'

  local assume_role_exports
  if [[ "$updated_folder" == ".circleci" ]]; then
    # Don't return an error when .circleci folder is updated.
    echo "INFO: Skipping deployment of $updated_folder."
    exit 0
  elif [[ "$updated_folder" =~ ^([^/]+)/.+$ ]]; then
    # Process the folder path, where the first group is the environment.
    assume_role_exports="$(assume_role_for_environment "${BASH_REMATCH[1]}")"
  else
    echo "ERROR: Could not extract environment from deployment path $updated_folder."
    exit 1
  fi

  local -a args=(--aws-region "$ecs_deploy_runner_region" --)
  # Determine which container to run.
  if [[ "$command" == "plan" ]] || [[ "$command" == "plan-all" ]] || [[ "$command" == "validate" ]] || [[ "$command" == "validate-all" ]]; then
    args+=(terraform-planner infrastructure-deploy-script)
  else
    args+=(terraform-applier infrastructure-deploy-script)
  fi

  args+=(--ref "$ref" --binary "terragrunt" --command "$command" --command-args "$command_args" --deploy-path "$updated_folder" --repo "$repo_url" --force-https true)

  # Add --apply-ref-for-destroy arg if running plan/apply -destroy or destroy.
  if [[ "$command_args" =~ "-destroy" ]] || [[ "$command" == "destroy" ]]; then
    args+=(--apply-ref-for-destroy "$source_ref")
  fi

  echo "Running infrastructure-deployer with args: ${args[@]}"

  (eval "$assume_role_exports" && infrastructure-deployer "${args[@]}")
}

function run {
  local -r source_ref="$1"
  local -r ref="$2"
  local -r command="$3"

  # We must export the functions and vars so that they can be invoked through xargs
  export -f route
  export -f invoke_infrastructure_deployer
  export -f assume_role_for_environment
  export -f get_git_root
  export -f get_git_origin_url

  # Use git-updated-folders to find all the terragrunt modules that changed, and pipe that via xargs to the
  # infrastructure-deployer.
  local updated_folders
  updated_folders="$(git-updated-folders --source-ref "$source_ref" --target-ref "$ref" --terragrunt --ext yaml --ext yml --exclude-deleted)"

  # Use git-updated-folders to find all the terragrunt modules that were deleted, and pipe that via xargs to the
  # infrastructure-deployer.
  local deleted_folders
  deleted_folders="$(git-updated-folders --source-ref "$source_ref" --target-ref "$ref" --terragrunt --ext yaml --ext yml --include-deleted-only)"

  if [[ -z "$deleted_folders" ]]; then
    echo "No modules were deleted. Skipping $command."
  else
    echo "The following modules were deleted:"
    echo "$deleted_folders"
    local command_args
    command_args="$([[ "$command" == echo "destroy" ]] && "" || echo "-destroy")"
    echo "Running $command $command_args on each deleted module."
    echo "$deleted_folders" \
      | xargs -r -I{} -n1 bash -c "set -o pipefail -e; echo \"Destroying {}\"; route {} \"$ref\" \"$command\" \"$command_args\" \"$source_ref\""
  fi

  # Run plan or apply on modified modules.
  if [[ -z "$updated_folders" ]]; then
    echo "No modules were updated. Skipping $command."
  else
    echo "The following modules were updated:"
    echo "$updated_folders"
    echo "Running $command on each updated module."
    echo "$updated_folders" \
      | xargs -r -I{} -n1 bash -c "set -o pipefail -e; echo \"Deploying {}\"; route {} \"$ref\" \"$command\""
  fi
}

run "$@"
