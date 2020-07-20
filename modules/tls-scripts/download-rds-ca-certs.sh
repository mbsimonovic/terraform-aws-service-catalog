#!/bin/bash
# Download the CA certs for RDS so that the applications validate the certs when connecting to RDS over SSL.
#
# Script dependencies:
# - curl

set -e

readonly RDS_CA_BUNDLE_URL="https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem"

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

if [[ "$#" -ne 1 ]]; then
  log "ERROR: expected exactly 1 argument, but got $#."
  log "Usage: download-rds-ca-certs.sh PATH"
  exit 1
fi

readonly download_path="$1"

if [[ -f "$download_path" ]]; then
  log "$download_path already exists. Will not download again."
else
  assert_is_installed "curl"

  log "Downloading $RDS_CA_BUNDLE_URL to $download_path"
  mkdir -p "$(dirname $download_path)"
  curl -s "$RDS_CA_BUNDLE_URL" > "$download_path"
fi
