#!/bin/bash
#
# A script run in User Data of the OpenVPN Server during boot.
#
# Note that this script expects to be running in an AMI generated by the Packer template openvpn-server.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Include common functions
source /etc/user-data/user-data-common.sh


function init_openvpn {
  local -r ca_country="$1"
  local -r ca_state="$2"
  local -r ca_locality="$3"
  local -r ca_org="$4"
  local -r ca_org_unit="$5"
  local -r ca_email="$6"
  local -r backup_bucket_name="$7"
  local -r kms_key_arn="$8"
  local -r key_size="$9"
  shift 9
  local -r ca_expiration_days="$1"
  local -r cert_expiration_days="$2"
  local -r vpn_subnet="$3"
  shift 3
  local -a routes=()

  while [[ $# -gt 0 ]]; do
    local route="$1"
    routes+=("--vpn-route" "$route")
    shift 1
  done

  echo 'Initializing PKI and Copying OpenVPN config into place...'
  init-openvpn  \
   --country "$ca_country"  \
   --state "$ca_state"  \
   --locality "$ca_locality"  \
   --org "$ca_org"  \
   --org-unit "$ca_org_unit"  \
   --email "$ca_email"  \
   --s3-bucket-name "$backup_bucket_name"  \
   --kms-key-id "$kms_key_arn" \
   --key-size "$key_size" \
   --ca-expiration-days "$ca_expiration_days" \
   --cert-expiration-days "$cert_expiration_days" \
   --vpn-subnet "$vpn_subnet" \
   "$${routes[@]}" # Need a double dollar-sign here to avoid Terraform interpolation
}

function start_openvpn {
  local -r queue_region="$1"

  echo 'Restarting OpenVPN...'
  /etc/init.d/openvpn restart

  echo 'Starting Certificate Request/Revoke Daemons...'
  run-process-requests --region "$queue_region" --request-url "${request_queue_url}"
  run-process-revokes --region "$queue_region" --revoke-url "${revocation_queue_url}"

  touch /etc/openvpn/openvpn-init-complete
}

# The variable below are interpolated from Terraform
# See: https://www.terraform.io/docs/configuration/expressions.html#interpolation
attach_eip "${eip_id}"
init_openvpn "${ca_country}" "${ca_state}" "${ca_locality}" "${ca_org}" "${ca_org_unit}" "${ca_email}" "${backup_bucket_name}" "${kms_key_arn}" "${key_size}" "${ca_expiration_days}" "${cert_expiration_days}" "${vpn_subnet}" ${routes}
start_openvpn "${queue_region}"
