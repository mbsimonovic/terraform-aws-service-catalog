#!/bin/bash
# This script will automatically create a CA cert and a TLS cert signed by that CA, assuming those certs don't already
# exist. The TLS cert private key will be encrypted with gruntkms. Optionally, this script can also upload the cert to
# IAM, so it can be used with an ELB or ALB.
#
# These certs are meant for private/internal use only, such as to set up end-to-end encryption within an AWS account.
# The only IP address in the cert will be 127.0.0.1 and localhost, so you can test your servers locally. You can also
# use the servers with the ELB or ALB, as the AWS load balancers don't verify the CA.
#
# Note: You must be authenticated to the AWS account for KMS based encryption and uploading to IAM to work.
#
# Script dependencies:
# - gruntkms
# - terraform
# - git
# - aws CLI
# - jq

set -e

if [[ -z $AWS_ACCESS_KEY_ID ]] || [[ -z $AWS_SECRET_ACCESS_KEY ]]; then
  echo "ERROR: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not set."
  exit 1
fi

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

readonly VAULT_BLUEPRINT_CLONE_URL="https://github.com/hashicorp/terraform-aws-vault.git"
readonly VAULT_BLUEPRINT_CHECKOUT_PATH="/tmp/vault-blueprint"
readonly VAULT_TLS_MODULE_PATH="/tmp/vault-blueprint/modules/private-tls-cert"
readonly TLS_PATH="/tmp/tls"

readonly DEFAULT_DNS_NAMES=("localhost")
readonly DEFAULT_IP_ADDRESSES=("127.0.0.1")

function print_usage {
  log
  log "Usage: create-tls-cert.sh [OPTIONS]"
  log
  log "This script will automatically create a CA cert and a TLS cert signed by that CA, assuming those certs don't already exist. The TLS cert private key will be encrypted with gruntkms. Optionally, this script can also upload the cert to IAM, so it can be used with an ELB or ALB."
  log
  log "Arguments:"
  log
  log "  --ca-path\t\tThe path to write the CA public key to. Required."
  log "  --cert-path\t\tThe path to write the TLS cert public key to. Required."
  log "  --key-path\t\tThe path to write the TLS cert private key to. This file will be encrypted with gruntkms. Required."
  log "  --dns-name\tA custom DNS name to associate with the cert. May be specified more than once. Optional. Default: ${DEFAULT_DNS_NAMES[@]}"
  log "  --ip-address\tA custom IP address to associate with the cert. May be specified more than once. Optional. Default: ${DEFAULT_IP_ADDRESSES[@]}"
  log "  --no-dns-names\tIf set, the cert won't be associated with any DNS names."
  log "  --no-ips\tIf set, the cert won't be associated with any IP addresses."
  log "  --company-name\tThe name of the company this cert is for. Required."
  log "  --upload-to-iam\tIf specified, the cert will be uploaded to IAM (for use with an ELB or ALB) and its ARN will be written to stdout. Optional."
  log "  --cert-name-in-iam\tThe name to use for the cert when uploading to IAM. Only used if --upload-to-iam is set."
  log "  --kms-key-id\t\tThe ID of the CMK to use for encryption. This value can be a globally unique identifier (e.g. 12345678-1234-1234-1234-123456789012), a fully specified ARN (e.g. arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012), or an alias name prefixed by \"alias/\" (e.g. alias/MyAliasName). Optional."
  log "  --aws-region\t\tThe AWS region where the kms-key lives. Required if --kms-key-id is set."
  log "  --role-arn\t\tThe AWS ARN of the IAM role to assume. Optional."
  log
  log "Examples:"
  log
  log "  create-tls-cert.sh --ca-path ca.crt.pem --cert-path my-app.crt.pem --key-path my-app.key.pem --company-name Acme"
  log "  create-tls-cert.sh --ca-path ca.crt.pem --cert-path my-app.crt.pem --key-path my-app.key.pem --company-name Acme --upload-to-iam --kms-key-id alias/cmk-dev --aws-region us-east-1"
}

# The Vault blueprint has a Terraform module that can be used to generate private TLS certs
function clone_vault_blueprint {
  local -r checkout_path="$1"

  if [[ -d "$checkout_path" ]]; then
    log "$checkout_path exists already. Will not clone Vault blueprint again."
  else
    log "Cloning Vault blueprint to $checkout_path"
    git clone "$VAULT_BLUEPRINT_CLONE_URL" "$checkout_path"
  fi
}

function cleanup_vault_blueprint {
  local -r checkout_path="$1"

  log "Cleaning up $checkout_path"
  rm -r "$checkout_path"
}

# Use the TLS module in the vault-aws-blueprint to generate a CA public key and a TLS cert public and private key
# signed by the CA.
function generate_tls_cert {
  local -r ca_public_key_path="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r company_name="$4"
  local -r tls_module_path="$5"
  local -r dns_names="$6"
  local -r ip_addresses="$7"

  local -r owner=$(whoami)
  local -r validity_period_hours="43800" # 5 years

  local -a args=()
  args+=("apply")
  args+=("-input=false")
  args+=("-auto-approve")
  args+=("-var" "ca_public_key_file_path=$ca_public_key_path")
  args+=("-var" "public_key_file_path=$cert_public_key_path")
  args+=("-var" "private_key_file_path=$cert_private_key_path")
  args+=("-var" "owner=$owner")
  args+=("-var" "organization_name=$company_name")
  args+=("-var" "ca_common_name=$company_name CA")
  args+=("-var" "common_name=$company_name private TLS cert")
  args+=("-var" "dns_names=[$dns_names]")
  args+=("-var" "ip_addresses=[$ip_addresses]")
  args+=("-var" "validity_period_hours=$validity_period_hours")
  args+=("-state=$tls_module_path/terraform.tfstate")
  args+=("-backup=-")

  log "Using Terraform module $tls_module_path to generate TLS certs"
  log "terraform ${args[@]}"
  (cd "$tls_module_path" && terraform "${args[@]}" 1>&2)
}

# Delete the Terraform state files, if they exist, from the Vault TLS module. The state files store the TLS cert
# private key, so we want to be sure to delete them so we don't leave this secret, unencrypted, lying around on the
# hard drive.
function cleanup_tls_module_terraform_state {
  local -r tls_module_path="$1"

  log "Cleaning up Terraform state files in $tls_module_path"
  rm -f "$tls_module_path"/terraform.tfstate
}

function encrypt_private_key {
  local -r cert_private_key_path="$1"
  local -r kms_key_id="$2"
  local -r aws_region="$3"
  local -r encrypted_cert_private_key_path="$cert_private_key_path.kms.encrypted"

  if [[ -z "$kms_key_id" || -z "$aws_region" ]]; then
    log "WARNING: --kms-key-id or --aws-region not specified. Will NOT be encrypting the TLS cert private key."
    return
  fi

  log "Encrypting private key at $cert_private_key_path with KMS key $kms_key_id"

  local private_key_plaintext
  local private_key_ciphertext
  private_key_plaintext=$(cat "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path")
  private_key_ciphertext=$(gruntkms encrypt --plaintext "$private_key_plaintext" --aws-region "$aws_region" --key-id "$kms_key_id")
  echo -n "$private_key_ciphertext" > "${VAULT_TLS_MODULE_PATH}/$encrypted_cert_private_key_path"
  log "Stored encrypted key as ${VAULT_TLS_MODULE_PATH}/$encrypted_cert_private_key_path"
  log "Removing original unencrypted key"
  rm "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path"
}

function prepare_folders {
  local -r ca_public_key_path="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"

  mkdir -p "$(dirname "$ca_public_key_path")"
  mkdir -p "$(dirname "$cert_public_key_path")"
  mkdir -p "$(dirname "$cert_private_key_path")"
}

function move_files {
  local -r ca_public_key_path="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r kms_key_id="$4"
  local -r aws_region="$5"

  log "Moving generated files to ${TLS_PATH}"
  mkdir -p "${TLS_PATH}/"

  if [[ -z $kms_key_id ]] || [[ -z $aws_region ]]; then
    mv "${VAULT_TLS_MODULE_PATH}/$ca_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path" "${TLS_PATH}/"
  else
    mv "${VAULT_TLS_MODULE_PATH}/$ca_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path.kms.encrypted" "${TLS_PATH}/"
  fi
}

function terraform_init {
  local -r tls_module_path="$1"
  log "Running terraform init in $tls_module_path"
  (cd "$tls_module_path" && terraform init 1>&2)
}

function exit_if_cert_file_exists {
  local -r path="$1"
  local -r should_upload_to_iam="$2"
  local -r cert_name="$3"
  local -r aws_region="$4"

  if [[ -f "${TLS_PATH}/$path" ]]; then
    log "${TLS_PATH}/$path already exists. Will not generate again."
    print_cert_arn_from_iam "$should_upload_to_iam" "$cert_name" "$aws_region"
    exit 0
  fi
}

function print_cert_arn_from_iam {
  local -r should_upload_to_iam="$1"
  local -r cert_name="$2"
  local -r aws_region="$3"

  if [[ "$should_upload_to_iam" != "true" ]]; then
    return
  fi

  log "Looking up ARN for TLS cert $cert_name in IAM in $aws_region"

  local output
  local cert_arn

  output=$(aws iam get-server-certificate --region "$aws_region" --server-certificate-name "$cert_name")
  cert_arn="$(echo "$output" | jq -r '.ServerCertificate.ServerCertificateMetadata.Arn')"

  echo -n "$cert_arn"
}

function upload_to_iam {
  local -r should_upload_to_iam="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r cert_name="$4"
  local -r aws_region="$5"

  if [[ "$should_upload_to_iam" != "true" ]]; then
    log "--upload-to-iam flag not set, so will not upload cert to IAM"
    return
  fi

  log "Uploading the cert to IAM with the name $cert_name"

  local output
  local cert_arn

  output=$(aws iam upload-server-certificate --region "$aws_region" --server-certificate-name "$cert_name" --certificate-body "file://${VAULT_TLS_MODULE_PATH}/$cert_public_key_path" --private-key "file://${VAULT_TLS_MODULE_PATH}/$cert_private_key_path")
  cert_arn="$(echo "$output" | jq -r '.ServerCertificateMetadata.Arn')"

  log "Certificate uploaded. ARN: $cert_arn."
  echo -n "$cert_arn"
}

function do_create {
  local -r ca_public_key_path="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r company_name="$4"
  local -r kms_key_id="$5"
  local -r aws_region="$6"
  local -r upload_to_iam="$7"
  local -r cert_name_in_iam="$8"
  local -r dns_names_str="${9}"
  local -r ip_addresses_str="${10}"
  local -r no_dns_names="${11}"
  local -r no_ips="${12}"

  if [[ "$upload_to_iam" == true && -z "$cert_name_in_iam" ]]; then
    log "The --cert-name-in-iam parameter cannot be empty if the --upload-to-iam flag is set"
    exit 1
  fi

  exit_if_cert_file_exists "$ca_public_key_path" "$upload_to_iam" "$cert_name_in_iam" "$aws_region"
  exit_if_cert_file_exists "$cert_public_key_path" "$upload_to_iam" "$cert_name_in_iam" "$aws_region"
  exit_if_cert_file_exists "$cert_private_key_path" "$upload_to_iam" "$cert_name_in_iam" "$aws_region"

  if [[ "$no_dns_names" == "true" ]]; then
    log "The --no-dns-names flag is set, so won't associate cert with any DNS names."
    dns_names_str=""
  fi

  if [[ "$no_ips" == "true" ]]; then
    log "The --no-ips flag is set, so won't associate cert with any IP addresses."
    ip_addresses_str=""
  fi

  log "Staring TLS cert generation..."

  clone_vault_blueprint "$VAULT_BLUEPRINT_CHECKOUT_PATH"
  cleanup_tls_module_terraform_state "$VAULT_TLS_MODULE_PATH"
  prepare_folders "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path"
  terraform_init "$VAULT_TLS_MODULE_PATH"
  generate_tls_cert "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path" "$company_name" "$VAULT_TLS_MODULE_PATH" "$dns_names_str" "$ip_addresses_str"
  cleanup_tls_module_terraform_state "$VAULT_TLS_MODULE_PATH"
  upload_to_iam "$upload_to_iam" "$cert_public_key_path" "$cert_private_key_path" "$cert_name_in_iam" "$aws_region"
  encrypt_private_key "$cert_private_key_path" "$kms_key_id" "$aws_region"
  move_files "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path" "$kms_key_id" "$aws_region"
  cleanup_vault_blueprint "$VAULT_BLUEPRINT_CHECKOUT_PATH"

  log "Done with TLS cert generation!"
}

function run {
  local ca_public_key_path
  local cert_public_key_path
  local cert_private_key_path
  local company_name
  local kms_key_id
  local aws_region
  local role_arn
  local upload_to_iam="false"
  local cert_name_in_iam
  local -a dns_names=()
  local -a ip_addresses=()
  local no_dns_names="false"
  local no_ips="false"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --ca-path)
        ca_public_key_path="$2"
        shift
        ;;
      --cert-path)
        cert_public_key_path="$2"
        shift
        ;;
      --key-path)
        cert_private_key_path="$2"
        shift
        ;;
      --upload-to-iam)
        upload_to_iam="true"
        ;;
      --cert-name-in-iam)
        cert_name_in_iam="$2"
        shift
        ;;
      --company-name)
        company_name="$2"
        shift
        ;;
      --dns-name)
        dns_names+=("$2")
        shift
        ;;
      --ip-address)
        ip_addresses+=("$2")
        shift
        ;;
      --no-dns-names)
        no_dns_names="true"
        ;;
      --no-ips)
        no_ips="true"
        ;;
      --kms-key-id)
        kms_key_id="$2"
        shift
        ;;
      --aws-region)
        aws_region="$2"
        shift
        ;;
      --role-arn)
        role_arn="$2"
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--ca-public-key-path" "$ca_public_key_path"
  assert_not_empty "--cert-public-key-path" "$cert_public_key_path"
  assert_not_empty "--cert-private-key-path" "$cert_private_key_path"
  assert_not_empty "--company-name" "$company_name"

  assert_is_installed "gruntkms"
  assert_is_installed "terraform"
  assert_is_installed "git"
  assert_is_installed "aws"
  assert_is_installed "jq"

  if [[ ! -z "$role_arn" ]]; then
    assume_iam_role "$role_arn"
  fi

  if [[ "${#dns_names[@]}" -eq 0 ]]; then
    dns_names="${DEFAULT_DNS_NAMES[@]}"
  fi

  if [[ "${#ip_addresses[@]}" -eq 0 ]]; then
    ip_addresses="${DEFAULT_IP_ADDRESSES[@]}"
  fi

  local dns_names_str="\"$(join "\",\"" "${dns_names[@]}")\""
  local ip_addresses_str="\"$(join "\",\"" "${ip_addresses[@]}")\""

  (do_create "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path" "$company_name" "$kms_key_id" "$aws_region" "$upload_to_iam" "$cert_name_in_iam" "$dns_names_str" "$ip_addresses_str" "$no_dns_names" "$no_ips")
}

run "$@"
