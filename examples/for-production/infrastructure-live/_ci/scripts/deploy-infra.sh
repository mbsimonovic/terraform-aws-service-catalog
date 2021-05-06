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
  elif [[ "$updated_folder" =~ ^.+/ecs-deploy-runner(/.+)?$ ]]; then
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

  local repo_url
  repo_url="$(get_git_origin_url)"

  local -r ecs_deploy_runner_region='us-west-2'

  local assume_role_exports
  if [[ $updated_folder =~ ^([^/]+)/.+$ ]]; then
    assume_role_exports="$(assume_role_for_environment "${BASH_REMATCH[1]}")"
  else
    echo "ERROR: Could not extract environment from deployment path $updated_folder."
    exit 1
  fi

  local -a args=(--aws-region "$ecs_deploy_runner_region" --)
  # Determine which container to run
  if [[ "$command" == "plan" ]] || [[ "$command" == "plan-all" ]] || [[ "$command" == "validate" ]] || [[ "$command" == "validate-all" ]]; then
    args+=(terraform-planner infrastructure-deploy-script)
  else
    args+=(terraform-applier infrastructure-deploy-script)
  fi
  # Determine args for infrastructure-deploy-script and invoke it
  args+=(--ref "$ref" --binary "terragrunt" --command "$command" --deploy-path "$updated_folder" --repo "$repo_url")

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

  # Use git-updated-folders to find all the terragrunt modules that changed, and pipe that through to the
  # infrastructure-deployer.
  local updated_folders
  updated_folders="$(git-updated-folders --source-ref "$source_ref" --target-ref "$ref" --terragrunt --ext yaml --ext yml)"

  if [[ -z "$updated_folders" ]]; then
    echo "No modules were updated. Skipping $command."
  else
    echo "The following folders were updated:"
    echo "$updated_folders"
    echo "$updated_folders" \
      | xargs -r -I{} -n1 bash -c "set -o pipefail -e; echo \"Deploying {}\"; route {} \"$ref\" \"$command\""
  fi
}

run "$@"
