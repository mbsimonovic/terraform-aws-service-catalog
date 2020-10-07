#!/bin/bash
# This script creates a self-signed TLS certificate. The certificate is signed by a CA temporarily generated
# at runtime and then deleted, leaving only the CA public key behind so you can validate the TLS certificate.
# By default, the script writes the TLS certificate public and private key and the CA public key to local
# disk. However, the script can also optionally (a) store the cert in AWS Secrets Manager, so your apps
# running in AWS can securely access it, (b) upload the certs to AWS Certificate Manager, so AWS services
# such as ELBs can securely access it, and/or (c) encrypt the private key locally with KMS to protect it.
#
# These certs are meant for private/internal use only, such as to set up end-to-end encryption within an AWS
# account. By default, the only IP address in the cert will be 127.0.0.1 and the only dns name will
# be localhost, so you can test your servers locally. You can also use the servers with the ELB or ALB, as
# the AWS load balancers don't verify the CA.
#
# Note: You must be authenticated to the AWS account for KMS encryption, storing in Secrets Manager, and
# uploading to ACM to work.
#
# Dependencies:
# - aws CLI
# - gruntkms
# - jq
# Note: These dependencies are automatically included in the Dockerfile in this module folder.

set -e

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

function set_paths {
  local -r tls_path="$1"

  readonly TLS_PATH="$tls_path"
  readonly CERT_PUBLIC_KEY_PATH="$TLS_PATH/app.crt"
  readonly CERT_PRIVATE_KEY_PATH="$TLS_PATH/app.key"
  readonly ENCRYPTED_CERT_PRIVATE_KEY_PATH="$TLS_PATH/app.key.kms.encrypted"
  readonly CA_PUBLIC_KEY_PATH="$TLS_PATH/CA.crt"
}

readonly DEFAULT_DNS_NAMES=("localhost")
readonly DEFAULT_IP_ADDRESSES=("127.0.0.1")

function print_usage {
  log
  log "Usage: create-tls-cert.sh [OPTIONS]"
  log
  log "This script creates a self-signed TLS certificate. The certificate is signed by a CA temporarily generated at runtime and then deleted, leaving only the CA public key behind so you can validate the TLS certificate. By default, the script writes the TLS certificate public and private key and the CA public key to local disk. However, the script can also optionally (a) store the cert in AWS Secrets Manager, so your apps running in AWS can securely access it, (b) upload the data to AWS Certificate Manager, so AWS services such as ELBs can securely access it, and/or (c) encrypt the private key locally with KMS to protect it."
  log
  log "These certs are meant for private/internal use only, such as to set up end-to-end encryption within an AWS account. By default, the only IP address in the cert will be 127.0.0.1 and the only dns name will be localhost, so you can test your servers locally. You can also use the servers with the ELB or ALB, as the AWS load balancers don't verify the CA."
  log
  log "Note: You must be authenticated to the AWS account for KMS encryption, storing in Secrets Manager, and uploading to ACM to work."
  log
  log "Required Arguments:"
  log
  log "  --cn\t\t\tThe Common Name (CN) for the certificate: e.g., what domain name to issue it for."
  log "  --country\t\tThe two-letter country code for where your company is located."
  log "  --state\t\tThe two-letter state code for where your company is located."
  log "  --city\t\tThe name of the city for where your company is located."
  log "  --org\t\t\tThe name of organization in your company."
  log
  log "Optional Arguments for Cert Creation:"
  log
  log "  --dns-name\t\tA custom DNS name to associate with the cert, in addition to the default. May be specified more than once. Default: ${DEFAULT_DNS_NAMES[@]}"
  log "  --ip-address\t\tA custom IP address to associate with the cert, in addition to the default. May be specified more than once. Default: ${DEFAULT_IP_ADDRESSES[@]}"
  log "  --no-dns-names\tIf set, the cert won't be associated with any DNS names."
  log "  --no-ips\t\tIf set, the cert won't be associated with any IP addresses."
  log "  --role-arn\t\tThe AWS ARN of the IAM role to assume."
  log "  --store-path\t\tThe path where the cert files should be stored locally. Default: tls/certs/."
  log
  log "Optional Arguments for Cert Encryption and Storage:"
  log
  log "  --aws-region\t\tThe AWS region corresponding to AWS Secrets Manager, AWS Certificate Manager, and where the kms-key lives, if these other options are set."
  log "  --store-in-sm\t\tIf provided, the cert will be stored in AWS Secrets Manager. If --kms-key-id is provided, it will be used to encrypt the cert. Otherwise the default CMK will be used."
  log "  --secret-name\t\tIf --store-in-sm is set, this is the name of the secret you'd like to use to store the cert in AWS Secrets Manager."
  log "  --upload-to-acm\tIf provided, the cert will be uploaded to AWS Certificate Manager and its ARN will be written to stdout."
  log "  --kms-key-id\t\tThe KMS key to use for encryption. If provided, the TLS cert private key will be encrypted locally. If --store-in-sm is provided, this key will be used to encrypt the cert in AWS Secrets Manager. This value can be a globally unique identifier (e.g. 12345678-1234-1234-1234-123456789012), a fully specified ARN (e.g. arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012), or an alias name prefixed by \"alias/\" (e.g. alias/MyAliasName)."
  log
  log "Examples:"
  log
  log "  create-tls-cert.sh \\"
  log "    --cn acme.com \\"
  log "    --country US \\"
  log "    --state AZ \\"
  log "    --city Phoenix \\"
  log "    --org Acme \\"
  log "    --store-in-sm \\"
  log "    --secret-name my-tls-secret \\"
  log "    --aws-region us-east-1 \\"
  log "    --kms-key-id alias/dedicated-test-key"
  log
  log "  create-tls-cert.sh \\"
  log "    --cn acme.com \\"
  log "    --country US \\"
  log "    --state AZ \\"
  log "    --city Phoenix \\"
  log "    --org Acme \\"
  log "    --store-in-sm \\"
  log "    --secret-name my-tls-secret \\"
  log "    --aws-region us-east-1 \\"
  log "    --kms-key-id alias/dedicated-test-key \\"
  log "    --upload-to-acm"
}

function encrypt_private_key {
  local -r aws_region="$1"
  local -r kms_key_id="$2"

  if [[ -z "$kms_key_id" ]]; then
    log "⚠️ --kms-key-id not specified. Will not encrypt TLS Cert private key."
    return
  fi

  log "Encrypting private key at $CERT_PRIVATE_KEY_PATH with KMS key $kms_key_id"

  local private_key_plaintext
  local private_key_ciphertext
  private_key_plaintext=$(cat "$CERT_PRIVATE_KEY_PATH")
  private_key_ciphertext=$(gruntkms encrypt --plaintext "$private_key_plaintext" --aws-region "$aws_region" --key-id "$kms_key_id")
  echo -n "$private_key_ciphertext" > "$ENCRYPTED_CERT_PRIVATE_KEY_PATH"
  log "Stored encrypted key as $ENCRYPTED_CERT_PRIVATE_KEY_PATH"
  rm "$CERT_PRIVATE_KEY_PATH"
  log "Removed original unencrypted key at $CERT_PRIVATE_KEY_PATH."
}

# Stores the public and private key and CA public key into a JSON object in Secrets Manager
function store_tls_certs_in_secrets_manager {
  local -r aws_region="$1"
  local -r secret_name="$2"
  local -r kms_key_id="$3"
  local -r store_in_sm="$4"
  local -r secret_description="The private key generated by create-tls-cert."

  if [[ "$store_in_sm" != "true" ]]; then
    log "--store-in-sm flag not set. Will not store cert in Secrets Manager."
    return
  fi

  log "Storing TLS Cert in AWS Secrets Manager..."

  local public_key_plaintext
  local private_key_plaintext
  local ca_public_key_plaintext
  local tls_secret_json
  local store_secret_response

  private_key_plaintext=$(cat "$CERT_PRIVATE_KEY_PATH")
  public_key_plaintext=$(cat "$CERT_PUBLIC_KEY_PATH")
  ca_public_key_plaintext=$(cat "$CA_PUBLIC_KEY_PATH")

  tls_secret_json=$(render_tls_secret_json "$public_key_plaintext" "$private_key_plaintext" "$ca_public_key_plaintext")
  store_secret_response=$(store_in_secrets_manager "$secret_name" "$secret_description" "$tls_secret_json" "$aws_region" "$kms_key_id")

  # Extract the ARN of the tls secret from AWS Secrets Manager
  tls_secret_arn=$(echo "$store_secret_response" | jq '.ARN')

  if [[ -n "$tls_secret_arn" ]]; then
    log "TLS Cert stored! Secret ARN: $tls_secret_arn"
  fi
}

function upload_to_acm {
  local -r aws_region="$1"
  local -r should_upload_to_acm="$2"

  if [[ "$should_upload_to_acm" != "true" ]]; then
    log "--upload-to-acm flag not set. Will not upload cert to ACM."
    return
  fi

  log "Uploading the certificate to ACM..."

  cert_arn=$(import_certificate_to_acm "$CERT_PUBLIC_KEY_PATH" "$CERT_PRIVATE_KEY_PATH" "$CA_PUBLIC_KEY_PATH" "$aws_region")

  log "Certificate uploaded! Certificate ARN will be printed on next line."
  echo $cert_arn
}

function render_tls_secret_json {
  local -r app_public_key="$1"
  local -r app_private_key="$2"
  local -r ca_public_key="$3"

  local -r json=$(cat <<END_HEREDOC
{
    "app": {
      "crt": "$app_public_key",
      "key": "$app_private_key",
      "ca": "$ca_public_key"
    }
}
END_HEREDOC
)

  echo -n "$json"
}

function do_create {
  local -r common_name="$1"
  local -r aws_region="$2"
  local -r upload_to_acm="$3"
  local -r secret_name="$4"
  local -r country="$5"
  local -r state="$6"
  local -r city="$7"
  local -r org="$8"
  local -r kms_key_id="$9"
  local -r san="${10}"
  local -r store_in_sm="${11}"
  local -r store_path="${12}"

  set_paths "$store_path"

  log "Starting TLS cert generation..."

  "generate-self-signed-tls-cert.sh" \
    --cn "$common_name" \
    --country "$country" \
    --state "$state" \
    --city "$city" \
    --org "$org" \
    --dir "$store_path" \
    --size 2048 \
    --san "$san"

  store_tls_certs_in_secrets_manager "$aws_region" "$secret_name" "$kms_key_id" "$store_in_sm"
  upload_to_acm "$aws_region" "$upload_to_acm"
  encrypt_private_key "$aws_region" "$kms_key_id"

  log "🎉 Done with TLS cert generation!"
}

function run {
  local common_name
  local country
  local state
  local city
  local org
  local aws_region
  local role_arn
  local upload_to_acm="false"
  local store_in_sm="false"
  local kms_key_id
  local secret_name
  local -a dns_names=()
  local -a ip_addresses=()
  local no_dns="false"
  local no_ips="false"
  local store_path="/tls/certs"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --store-in-sm)
        store_in_sm="true"
        ;;
      --upload-to-acm)
        upload_to_acm="true"
        ;;
      --store-path)
        store_path="$2"
        shift
        ;;
      --cn)
        common_name="$2"
        shift
        ;;
      --country)
        country="$2"
        shift
        ;;
      --state)
        state="$2"
        shift
        ;;
      --city)
        city="$2"
        shift
        ;;
      --org)
        org="$2"
        shift
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
      --secret-name)
        secret_name="$2"
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
        no_dns="true"
        ;;
      --no-ips)
        no_ips="true"
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log "Unrecognized argument: $key"
        #print_usage
        exit 1
        ;;
    esac

    shift
  done

  # Required arguments
  assert_not_empty "--cn" "$common_name"
  assert_not_empty "--country" "$country"
  assert_not_empty "--state" "$state"
  assert_not_empty "--city" "$city"
  assert_not_empty "--org" "$org"

  # Optional arguments
  if [[ -n "$kms_key_id" ]] || [[ "$upload_to_acm" == "true" ]]; then
    assert_not_empty "--aws-region" "$aws_region"
  fi

  if [[ "$store_in_sm" == "true" ]] || [[ -n "$secret_name" ]]; then
    assert_not_empty "--aws-region" "$aws_region"
    assert_not_empty "--store-in-sm" "$store_in_sm"
    assert_not_empty "--secret-name" "$secret_name"
  fi

  # Required environment variables if the above optional arguments are given
  if [[ -n "$kms_key_id" ]] ||
    [[ "$upload_to_acm" == "true" ]] ||
    [[ "$store_in_sm" == "true" ]] ||
    [[ -n "$secret_name" ]]; then
    if [[ -z $AWS_ACCESS_KEY_ID ]] || [[ -z $AWS_SECRET_ACCESS_KEY ]]; then
      log "ERROR: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not set."
      exit 1
    fi
  fi

  assert_is_installed "aws"
  assert_is_installed "gruntkms"
  assert_is_installed "jq"

  if [[ -n "$role_arn" ]]; then
    assume_iam_role "$role_arn"
  fi

  # If no dns_names or ip_addresses were passed in, use the defaults
  if [[ "${#dns_names[@]}" -eq 0 ]]; then
    dns_names="${DEFAULT_DNS_NAMES[@]}"
  fi

  if [[ "${#ip_addresses[@]}" -eq 0 ]]; then
    ip_addresses="${DEFAULT_IP_ADDRESSES[@]}"
  fi

  local dns_names_str="DNS:\"$(join "\",DNS:\"" "${dns_names[@]}")\""
  local ip_addresses_str="IP:\"$(join "\",IP:\"" "${ip_addresses[@]}")\""

  # Blank them out if specified
  if [[ "$no_dns" == "true" ]]; then
    log "The --no-dns-names flag is set, so won't associate cert with any DNS names."
    dns_names_str=""
  fi

  if [[ "$no_ips" == "true" ]]; then
    log "The --no-ips flag is set, so won't associate cert with any IP addresses."
    ip_addresses_str=""
  fi

  # Join them into a SAN list
  local san
  if [[ -z "$dns_names_str" ]]; then
    san="$ip_addresses_str"
    if [[ -z "$ip_addresses_str" ]]; then
      san=""
    fi
  elif [[ -z "$ip_addresses_str" ]]; then
    san="$dns_names_str"
  else
    san="$dns_names_str,$ip_addresses_str"
  fi

  (do_create "$common_name" "$aws_region" "$upload_to_acm" "$secret_name" "$country" "$state" "$city" "$org" "$kms_key_id" "$san" "$store_in_sm" "$store_path")
}

run "$@"
