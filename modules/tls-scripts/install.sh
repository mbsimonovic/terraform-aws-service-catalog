#!/usr/bin/env bash
#
# Script used by gruntwork-install to install the TLS scripts module
#

set -e

# Locate the directory in which this script is located
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership and permissions of the scripts
chmod -R +x "${script_path}"/{create-tls-cert.sh,download-rds-ca-certs.sh,generate-trust-stores.sh,helpers.sh,generate-self-signed-tls-cert.sh}

# Expand the helpers scripts into the main script dir  
mv "${script_path}"/helpers/*.sh "${script_path}"

# Clean up the helpers directory
rm -rf "${script_path}/helpers"

