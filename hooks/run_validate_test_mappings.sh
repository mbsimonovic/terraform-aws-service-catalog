#!/bin/bash

# Get the repo root and add ".circleci" to the python path
readonly repo_root="$(git rev-parse --show-toplevel | tr -d '\n')"
PYTHONPATH="$repo_root/.circleci" python "$repo_root/hooks/validate_test_mappings.py"
