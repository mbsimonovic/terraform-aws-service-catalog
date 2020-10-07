#!/usr/bin/env bash
#
# Script used by gruntwork-install to install the TLS scripts module
#

set -e

# Locate the directory in which this script is located
readonly script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Move the bin files into /usr/local/bin
cp "${script_path}/{create-tls-cert.sh, download-rds-ca-certs.sh, generate-trust-stores.sh}" /usr/local/bin

# Change ownership and permissions
chmod +x "/usr/local/bin/{create-tls-cert.sh, download-rds-ca-certs.sh, generate-trust-stores.sh}"

