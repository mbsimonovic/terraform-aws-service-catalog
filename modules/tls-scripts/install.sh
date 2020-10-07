#!/usr/bin/env bash
#
# Script used by gruntwork-install to install the TLS scripts module
#

set -e

# Locate the directory in which this script is located
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Move the bin files into /usr/local/bin
cp "${script_path}"/{create-tls-cert.sh,download-rds-ca-certs.sh,generate-trust-stores.sh} /usr/local/bin

# Move the helpers directory into /usr/local/bin
cp -R "${script_path}"/helpers /usr/local/bin/helpers

# Change ownership and permissions of the scripts
chmod +x /usr/local/bin/{create-tls-cert.sh,download-rds-ca-certs.sh,generate-trust-stores.sh}

# Change ownership and permissions of the helpers
chmod -R +x /usr/local/bin/helpers
