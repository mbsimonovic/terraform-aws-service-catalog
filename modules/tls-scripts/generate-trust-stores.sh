#!/bin/bash
# This script is meant to be used to automatically generate a Key Store and Trust Store, which are typically used with
# Java apps to securely store SSL certificates. If they don't already exist, the Key Store, Trust Store, and public cert
# / CA will be generated to the specified paths, and the Key Store password will be stored in AWS Secrets Manager. The
# script writes the KMS-encrypted password for the Key Store to stdout.
#
# Note: You must be authenticated to the AWS account for KMS based encryption and uploading to IAM to work.
#
# Script dependencies:
# - gruntkms
# - terraform
# - git
# - pwgen
# - aws cli
# - keytool
# - openssl

set -e

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

readonly PACKAGE_KAFKA_CHECKOUT_PATH="/tmp/package-kafka"
readonly PACKAGE_KAFKA_CHECKOUT_URL="git@github.com:gruntwork-io/package-kafka.git"

readonly DEFAULT_KEYSTORE_PASSWORD_LENGTH=32

function print_usage {
  log
  log "Usage: generate-trust-stores.sh [OPTIONS]"
  log
  log "This script is meant to be used to automatically generate a Key Store and Trust Store, which are typically used with Java apps to securely store SSL certificates. If they don't already exist, the Key Store, Trust Store, and public cert / CA will be generated to the specified paths, and the Key Store password will be stored in AWS Secrets Manager. The script writes the KMS-encrypted password for the Key Store to stdout."
  log
  log "Required Arguments:"
  log
  log "  --keystore-name\t\t\tThe first part of the filename for all ssl output files. Ex: [keystore-name].server.keystore.[vpc_name].jks."
  log "  --store-path\t\t\t\tThe path to the folder where the Key Store, Trust Store, cert, and CA should be generated."
  log "  --vpc-name\t\t\t\tThe name of the VPC for which we're generating the Key Store, Trust Store, etc."
  log "  --company-name\t\t\tThe name of the company."
  log "  --company-org-unit\t\t\tThe name of the org unit in the company."
  log "  --company-city\t\t\tThe city the company is in."
  log "  --company-state\t\t\tThe state the company is in."
  log "  --company-country\t\t\tThe country the company is in."
  log "  --kms-key-id\t\tThe ID of the CMK to use for encryption. This value can be a globally unique identifier (e.g. 12345678-1234-1234-1234-123456789012), a fully specified ARN (e.g. arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012), or an alias name prefixed by \"alias/\" (e.g. alias/MyAliasName). Optional."
  log "  --aws-region\t\t\t\tThe AWS region where to store the keystore passwords in AWS Secrets Manager."
  log
  log "Optional Arguments:"
  log
  log "  --role-arn\t\tThe AWS ARN of the IAM role to assume. Optional."
  log "  --san-ip\t\t\t\tThe IP address to include in the SAN field on the generated cert. *May be repeated*."
  log "  --san-domain\t\t\t\tThe domain name to include in the SAN field on the generated cert. *May be repeated*."
  log "  --export-cert-key\t\t\tOptional boolean whether to export the generated self-signed certificate's private key. If not specified, private key will not be exported."
  log "  --export-cert-p8-key\t\t\tOptional boolean whether to export the generated self-signed certificate's private key in P8 format. If not specified, will not exported private key."
  log "  --generate-certs-in-one-folder\tOptional boolean. If present all cert/jsk/truststore files will be outputted into --store-path. Otherwise trust-store and jks will be in separate dirs."
  log
  log "Example:"
  log
  log "  generate-trust-stores.sh \\"
  log "    --keystore-name kafka \\"
  log "    --store-path /ssl \\"
  log "    --company-name Acme \\"
  log "    --company-org-unit IT \\"
  log "    --company-city Phoenix \\"
  log "    --company-state AZ \\"
  log "    --company-country US \\"
  log "    --kms-key-id alias/cmk-dev \\"
  log "    --aws-region us-east-1"
}

function generate_key_store_password {
  local -r keystore_name="$1"
  local -r vpc_name="$2"
  local -r aws_region="$3"

  generate_and_store_password "$vpc_name-$keystore_name-keystore-password" "$DEFAULT_KEYSTORE_PASSWORD_LENGTH" "The keystore password for $keystore_name in $vpc_name" "$aws_region"
}

function clone_package_kafka {
  local -r checkout_path="$1"

  if [[ -d "$checkout_path" ]]; then
    log "$checkout_path exists already. Will not clone package-kafka again."
  else
    log "Cloning package-kafka to $checkout_path"
    git clone "$PACKAGE_KAFKA_CHECKOUT_URL" "$checkout_path"
  fi
}

function generate_trust_stores {
  local store_path
  local vpc_name
  local company_name
  local company_org_unit
  local company_city
  local company_state
  local company_country
  local aws_region
  local role_arn
  local kms_key_id
  local keystore_name
  local -a san_ips=()
  local -a san_domains=()
  local export_cert_key=false
  local export_key_p8=false
  local output_all_in_one_folder="false"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --store-path)
        store_path="$2"
        shift
        ;;
      --vpc-name)
        vpc_name="$2"
        shift
        ;;
      --company-name)
        company_name="$2"
        shift
        ;;
      --company-org-unit)
        company_org_unit="$2"
        shift
        ;;
      --company-city)
        company_city="$2"
        shift
        ;;
      --company-state)
        company_state="$2"
        shift
        ;;
      --company-country)
        company_country="$2"
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
      --kms-key-id)
        kms_key_id="$2"
        shift
        ;;
      --keystore-name)
        keystore_name="$2"
        shift
        ;;
      --san-ip)
        san_ips+=("$2")
        shift
        ;;
      --san-domain)
        san_domains+=("$2")
        shift
        ;;
      --export-cert-key)
        export_cert_key=true
        ;;
      --export-cert-p8-key)
        export_key_p8=true
        ;;
      --generate-certs-in-one-folder)
        output_all_in_one_folder="true"
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log "ERROR: Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_is_installed "gruntkms"
  assert_is_installed "terraform"
  assert_is_installed "git"
  assert_is_installed "aws"
  assert_is_installed "pwgen"
  assert_is_installed "keytool"
  assert_is_installed "openssl"

  assert_not_empty "--store-path" "$store_path"
  assert_not_empty "--vpc-name" "$vpc_name"
  assert_not_empty "--company-name" "$company_name"
  assert_not_empty "--company-org-unit" "$company_org_unit"
  assert_not_empty "--company-city" "$company_city"
  assert_not_empty "--company-state" "$company_state"
  assert_not_empty "--company-country" "$company_country"
  assert_not_empty "--aws-region" "$aws_region"
  assert_not_empty "--kms-key-id" "$kms_key_id"
  assert_not_empty "--keystore-name" "$keystore_name"

  if [[ ! -z "$role_arn" ]]; then
    assume_iam_role "$role_arn"
  fi

  # package-kafka requires this structure with the keystore and truststore in separate folders
  # Preserve this as the default
  local key_store_path="$store_path/keystore/$keystore_name.server.keystore.$vpc_name.jks"
  local trust_store_path="$store_path/truststore/$keystore_name.server.truststore.$vpc_name.jks"

  # Optionally, if --generate-certs-in-one-folder was present, we will just dump out all ssl
  # related files into one ssl/ folder.
  if [[ "$output_all_in_one_folder" = true ]]; then
    key_store_path="$store_path/$keystore_name.server.keystore.$vpc_name.jks"
    trust_store_path="$store_path/$keystore_name.server.truststore.$vpc_name.jks"
  fi

  local -r cert_path="$store_path/$keystore_name.server.cert.$vpc_name.pem"
  local -r ca_path="$store_path/$keystore_name.server.ca.$vpc_name.pem"

  # To keep things simple, we use the same password for both the Key Store and Trust Store
  local key_store_password
  key_store_password=$(generate_key_store_password "$keystore_name" "$vpc_name" "$aws_region")

  if [[ -f "$key_store_path" && -f "$trust_store_path" ]]; then
    log "The Key Store at $key_store_path and Trust Store at $trust_store_path already exist. Will not create again."
  elif [[ -f "$key_store_path" || -f "$trust_store_path" ]]; then
    log "ERROR: One of the Key Store at $key_store_path and Trust Store at $trust_store_path already exists, but the other does not. This likely indicates a bug! Please investigate."
    exit 1
  else
    log "Generating Key Store to $key_store_path and Trust Store to $trust_store_path"

    clone_package_kafka "$PACKAGE_KAFKA_CHECKOUT_PATH"

    mkdir -p "$(dirname $key_store_path)"
    mkdir -p "$(dirname $trust_store_path)"
    mkdir -p "$(dirname $cert_path)"
    mkdir -p "$(dirname $ca_path)"

    local -a args=()

    args+=("--key-store-path"); args+=("$key_store_path");
    args+=("--trust-store-path"); args+=("$trust_store_path");
    args+=("--cert-path"); args+=("$cert_path");
    args+=("--ca-path"); args+=("$ca_path");
    args+=("--org"); args+=("$company_name");
    args+=("--org-unit"); args+=("$company_org_unit");
    args+=("--city"); args+=("$company_city");
    args+=("--state"); args+=("$company_state");
    args+=("--country"); args+=("$company_country");

    if [[ "$export_cert_key" = true ]]; then
      args+=("--out-cert-key-path"); args+=("$store_path/$keystore_name.server.cert.$vpc_name.key");
    fi

    if [[ "$export_key_p8" = true ]]; then
      args+=("--out-cert-p8-key-path"); args+=("$store_path/$keystore_name.server.cert.$vpc_name.key.p8");
    fi

    for cur_domain_name in "${san_domains[@]}"
    do
      args+=("--domain")
      args+=("$cur_domain_name")
    done

    for cur_ip in "${san_ips[@]}"
    do
      args+=("--ip")
      args+=("$cur_ip")
    done

    KEY_STORE_PASSWORD="$key_store_password" TRUST_STORE_PASSWORD="$key_store_password" "$PACKAGE_KAFKA_CHECKOUT_PATH/modules/generate-key-stores/generate-key-stores.sh" "${args[@]}" 1>&2
  fi

  local password_ciphertext
  password_ciphertext=$(gruntkms encrypt --plaintext "$key_store_password" --aws-region "$aws_region" --key-id "$kms_key_id")
  echo -n "$password_ciphertext"
}

generate_trust_stores "$@"
