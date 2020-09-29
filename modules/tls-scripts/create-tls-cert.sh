#!/bin/bash
# This script creates a CA cert and a TLS cert signed by that CA, assuming those certs don't already exist. The TLS
# cert is uploaded to AWS Secrets Manager in the region you provide. It is also saved to the tls/ sub-directory.
# Optionally, this script can also upload the cert to ACM, so it can be used with an ELB or ALB.
#
# These certs are meant for private/internal use only, such as to set up end-to-end encryption within an AWS account.
# The only IP address in the cert will be 127.0.0.1 and localhost, so you can test your servers locally. You can also
# use the servers with the ELB or ALB, as the AWS load balancers don't verify the CA.
#
# Note: You must be authenticated to the AWS account for uploading to ACM to work.
#
# Dependencies:
# - terraform
# - git
# - aws CLI
# - jq
# Note: These dependencies are automatically included in the Dockerfile in this module folder.

set -e

if [[ -z $AWS_ACCESS_KEY_ID ]] || [[ -z $AWS_SECRET_ACCESS_KEY ]]; then
  echo "ERROR: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not set."
  exit 1
fi

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

readonly VAULT_BLUEPRINT_CLONE_URL="https://github.com/hashicorp/terraform-aws-vault.git"
readonly VAULT_BLUEPRINT_CHECKOUT_PATH="/tls/vault-blueprint"
readonly VAULT_TLS_MODULE_PATH="/tls/vault-blueprint/modules/private-tls-cert"
readonly TLS_PATH="/tls/certs"

readonly DEFAULT_DNS_NAMES=("localhost")
readonly DEFAULT_IP_ADDRESSES=("127.0.0.1")

function print_usage {
  log
  log "Usage: create-tls-cert.sh [OPTIONS]"
  log
  log "This script creates a CA cert and a TLS cert signed by that CA, assuming those certs don't already exist. The TLS cert is uploaded to AWS Secrets Manager in the region you provide. It is also saved to the tls/ sub-directory. Optionally, this script can also upload the cert to ACM, so it can be used with an ELB or ALB."
  log
  log "Required Arguments:"
  log
  log "  --ca-path\t\tThe path to write the CA public key to."
  log "  --cert-path\t\tThe path to write the TLS cert public key to."
  log "  --key-path\t\tThe path to write the TLS cert private key to."
  log "  --secret-name\t\tThe name of the secret you'd like to use to store the cert in AWS Secrets Manager."
  log "  --company-name\tThe name of the company this cert is for."
  log "  --aws-region\t\tThe AWS region to use for AWS Secrets Manager and AWS Certificate Manager."
  log
  log "Optional Arguments:"
  log
  log "  --upload-to-acm\tIf specified, the cert will be uploaded to AWS Certificate Manager and its ARN will be written to stdout."
  log "  --role-arn\t\tThe AWS ARN of the IAM role to assume."
  log "  --dns-name\tA custom DNS name to associate with the cert. May be specified more than once. Default: ${DEFAULT_DNS_NAMES[@]}"
  log "  --ip-address\tA custom IP address to associate with the cert. May be specified more than once. Default: ${DEFAULT_IP_ADDRESSES[@]}"
  log "  --no-dns-names\tIf set, the cert won't be associated with any DNS names."
  log "  --no-ips\tIf set, the cert won't be associated with any IP addresses."
  log
  log "Examples:"
  log
  log "  create-tls-cert.sh \\"
  log "    --ca-path ca.crt.pem \\"
  log "    --cert-path my-app.crt.pem \\"
  log "    --key-path my-app.key.pem \\"
  log "    --secret-name my-tls-secrets \\"
  log "    --company-name Acme \\"
  log "    --aws-region us-east-1"
  log
  log "  create-tls-cert.sh \\"
  log "    --ca-path ca.crt.pem \\"
  log "    --cert-path my-app.crt.pem \\"
  log "    --key-path my-app.key.pem \\"
  log "    --secret-name my-tls-secrets \\"
  log "    --company-name Acme \\"
  log "    --aws-region us-east-1 \\"
  log "    --upload-to-acm"
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

# Renders the public and private key as well as the CA public key into a JSON object that is stored in Secrets Manager
function store_tls_certs_in_secrets_manager {
  local -r cert_public_key_path="$1"
  local -r cert_private_key_path="$2"
  local -r ca_public_key_path="$3"
  local -r aws_region="$4"
  local -r secret_name="$5"
  local -r secret_description="The private key generated by create-tls-certs."

  log "Storing TLS Cert in AWS Secrets Manager..."

  local public_key_plaintext
  local private_key_plaintext
  local ca_public_key_plaintext
  local tls_secret_json
  local store_secret_response

  public_key_plaintext=$(cat "${VAULT_TLS_MODULE_PATH}/$cert_public_key_path")
  private_key_plaintext=$(cat "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path")
  ca_public_key_plaintext=$(cat "${VAULT_TLS_MODULE_PATH}/$ca_public_key_path")

  tls_secret_json=$(render_tls_secret_json "$public_key_plaintext" "$private_key_plaintext" "$ca_public_key_plaintext")
  store_secret_response=$(store_in_secrets_manager "$secret_name" "$secret_description" "$tls_secret_json" "$aws_region")

  # Extract the ARN of the tls secret in AWS Secrets Manager
  tls_secret_arn=$(echo "$store_secret_response" | jq '.ARN')

  log "TLS Cert stored! Secret ARN: $tls_secret_arn"
}

function upload_to_acm {
  local -r should_upload_to_acm="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r ca_public_key_path="$4"
  local -r aws_region="$5"

  if [[ "$should_upload_to_acm" != "true" ]]; then
    log "--upload-to-acm flag not set. Will not upload cert to ACM."
    return
  fi

  log "Uploading the certificate to ACM..."

  cert_arn=$(import_certificate_to_acm "$cert_public_key_path" "$cert_private_key_path" "$ca_public_key_path" "$aws_region")

  log "Certificate uploaded! Certificate ARN: $cert_arn"
}

function render_tls_secret_json {
  local -r app_public_key="$1"
  local -r app_private_key="$2"
  local -r app_ca_public_key="$3"

  local -r json=$(cat <<END_HEREDOC
{
    "app": {
      "crt": "$app_public_key",
      "key": "$app_private_key",
      "ca": "$app_ca_public_key"
    }
}
END_HEREDOC
)

  echo -n "$json"
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

  log "Moving generated files to ${TLS_PATH}"
  mkdir -p "${TLS_PATH}/"

  mv "${VAULT_TLS_MODULE_PATH}/$ca_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_public_key_path" "${VAULT_TLS_MODULE_PATH}/$cert_private_key_path" "${TLS_PATH}/"
}

function terraform_init {
  local -r tls_module_path="$1"
  log "Running terraform init in $tls_module_path"
  (cd "$tls_module_path" && terraform init 1>&2)
}

function exit_if_cert_file_exists {
  local -r path="$1"

  if [[ -f "${TLS_PATH}/$path" ]]; then
    log "${TLS_PATH}/$path already exists. Will not generate certificate again."
    log "Exiting."
    exit 0
  fi
}

function do_create {
  local -r ca_public_key_path="$1"
  local -r cert_public_key_path="$2"
  local -r cert_private_key_path="$3"
  local -r company_name="$4"
  local -r aws_region="$5"
  local -r upload_to_acm="$6"
  local -r dns_names_str="${7}"
  local ip_addresses_str="${8}"
  local -r no_dns_names="${9}"
  local -r no_ips="${10}"

  exit_if_cert_file_exists "$ca_public_key_path"
  exit_if_cert_file_exists "$cert_public_key_path"
  exit_if_cert_file_exists "$cert_private_key_path"

  if [[ "$no_dns_names" == "true" ]]; then
    log "--no-dns-names flag is set. Won't associate cert with any DNS names."
    dns_names_str=""
  fi

  if [[ "$no_ips" == "true" ]]; then
    log "--no-ips flag is set. Won't associate cert with any IP addresses."
    ip_addresses_str=""
  fi

  log "Starting TLS cert generation..."

  clone_vault_blueprint "$VAULT_BLUEPRINT_CHECKOUT_PATH"
  cleanup_tls_module_terraform_state "$VAULT_TLS_MODULE_PATH"
  prepare_folders "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path"
  terraform_init "$VAULT_TLS_MODULE_PATH"
  generate_tls_cert "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path" "$company_name" "$VAULT_TLS_MODULE_PATH" "$dns_names_str" "$ip_addresses_str"
  cleanup_tls_module_terraform_state "$VAULT_TLS_MODULE_PATH"
  store_tls_certs_in_secrets_manager "$cert_public_key_path" "$cert_private_key_path" "$ca_public_key_path" "$aws_region" "$secret_name"
  upload_to_acm "$upload_to_acm" "$cert_public_key_path" "$cert_private_key_path" "$ca_public_key_path" "$aws_region"
  move_files "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path"
  cleanup_vault_blueprint "$VAULT_BLUEPRINT_CHECKOUT_PATH"

  log "Done with TLS cert generation!"
}

function run {
  local ca_public_key_path
  local cert_public_key_path
  local cert_private_key_path
  local company_name
  local aws_region
  local role_arn
  local upload_to_acm="false"
  local -a dns_names=()
  local -a ip_addresses=()
  local no_dns_names="false"
  local no_ips="false"
  local secret_name

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
      --upload-to-acm)
        upload_to_acm="true"
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
      --aws-region)
        aws_region="$2"
        shift
        ;;
      --secret-name)
        secret_name="$2"
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
  assert_not_empty "--aws-region" "$aws_region"
  assert_not_empty "--secret-name" "$secret_name"

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

  (do_create "$ca_public_key_path" "$cert_public_key_path" "$cert_private_key_path" "$company_name" "$aws_region" "$upload_to_acm" "$dns_names_str" "$ip_addresses_str" "$no_dns_names" "$no_ips" "$secret_name")
}

run "$@"
