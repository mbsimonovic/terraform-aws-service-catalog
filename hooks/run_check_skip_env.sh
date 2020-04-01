#!/bin/bash

# Get the repo root, change directory to the hook, and run the go module
readonly repo_root="$(git rev-parse --show-toplevel | tr -d '\n')"
cd "$repo_root/hooks/check-skip-env"
go run .
