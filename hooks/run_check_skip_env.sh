#!/bin/bash

# Get the repo root, change directory to the hook, and run the go module
readonly repo_root="$(git rev-parse --show-toplevel | tr -d '\n')"

abspaths=()
for path in "$@"
do
  abspaths+=("$repo_root/$path")
done

cd "$repo_root/hooks/check-skip-env"
go run . "${abspaths[@]}"
