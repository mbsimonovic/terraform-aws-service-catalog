#!/bin/bash
#
# Script used to trigger infrastructure deployments via the infrastructure-deployer CLI utility by
# invoking build scripts.
#
# Required positional arguments, in order:
# - SOURCE_REF : The starting point for identifying all the changes. The diff between SOURCE_REF and REF will be
#                evaluated to determine all the changed files.
# - REF : The end point for identifying all the changes. The diff between SOURCE_REF and REF will be evaluated to
#         determine all the changed files.
#
# Assumptions by script:
# - The script is run from a git repo corresponding to live infrastructure configurations (e.g., terragrunt modules).
# - There exists a json file named accounts.json at the root of the repo that maps AWS account names to AWS account IDs.
# - The first folder in the repository corresponds to AWS account names, and the accounts.json file contains an entry
#   for each folder.
#

set -e
set -o pipefail

readonly DEFAULT_PARALLELISM=8

# Locate the directory in which this script is located, and use that to determine where the helper functions are.
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_path/helpers.sh"

# Function that will check the diff between HEAD and source ref to find all the build scripts that have changed.
function get_updated_build_scripts {
  local -r source_ref="$1"
  local -r ref="$2"

  # Assume any script named build_*.sh is a CI server build script that needs to be run.
  local -r build_script_regex="build_[^/[:space:]]+\\.sh$"

  local repo_root
  repo_root="$(get_git_root)"

  git -C "$repo_root" diff --name-only "$source_ref" 'HEAD' \
    | grep -E "$build_script_regex" || true \
    | sort -u
}

# Function to call the given build script by assuming the auto deploy IAM role in the target account prior to calling
# the script.
function call_build_script {
  local -r build_script="$1"

  local assume_role_exports
  if [[ $build_script =~ ^([^/]+)/.+$ ]]; then
    assume_role_exports="$(assume_role_for_environment "${BASH_REMATCH[1]}")"
  else
    echo "ERROR: Could not extract environment from build script $build_script."
    exit 1
  fi

  (eval "$assume_role_exports" && bash "$build_script")
}

function run {
  local -r source_ref="$1"
  local -r ref="$2"

  # We must export the functions and vars so that they can be invoked through xargs
  export -f call_build_script
  export -f assume_role_for_environment
  export -f get_git_root

  local updated_build_scripts
  updated_build_scripts="$(get_updated_build_scripts "$source_ref" "$ref")"

  if [[ -z "$updated_build_scripts" ]]; then
    echo "No build scripts were updated."
  else
    # For each updated build script, call it in a subshell, using xargs to maintain parallelism (up to 8 parallel
    # processes).
    echo "The following build scripts were updated:"
    echo "$updated_build_scripts"
    echo "$updated_build_scripts" \
      | xargs -r -I{} -n1 -P "$DEFAULT_PARALLELISM" \
          bash -c "set -o pipefail -e; echo \"Calling build script {}\"; call_build_script {}"
  fi
}

run "$@"
