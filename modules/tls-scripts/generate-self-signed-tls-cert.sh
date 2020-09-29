#!/usr/bin/env bash
# This is a simple script you can use to generate self-signed TLS certificates.

set -e

readonly DEFAULT_TLS_CERTS_DIR=$(pwd)
readonly DEFAULT_EXPIRATION_DAYS=3650
readonly DEFAULT_KEY_SIZE_BITS=4096
readonly DEFAULT_ALTERNATIVE_NAMES=""

function print_usage {
  echo
  echo "Usage: generate-self-signed-tls-cert.sh [OPTIONS]"
  echo
  echo "Generate a self-signed TLS certificate using openssl. This script will write the following files:"
  echo
  echo "  app.crt: The public key of the certificate."
  echo "  app.key: The private key of the certificate."
  echo "  CA.crt: The public key of the Certificate Authority (CA) that signed the certificate. This CA is generated at runtime and immediately deleted."
  echo
  echo "Required arguments:"
  echo
  echo -e "  --cn\t\tThe Common Name (CN) for the certificate: e.g., what domain name to issue it for."
  echo -e "  --country\tThe two-letter country code for where your company is located."
  echo -e "  --state\tThe two-letter state code for where your company is located."
  echo -e "  --city\tThe name of the city for where your company is located."
  echo -e "  --org\t\tThe name of organization in your company."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --dir\t\tThe directory where to output the TLS certificate. Default: current working dir."
  echo -e "  --expiration\tThe number of days after which the TLS certificate and CA expire. Default: $DEFAULT_EXPIRATION_DAYS."
  echo -e "  --size\tGenerate an RSA key of this size. Default: $DEFAULT_KEY_SIZE_BITS."
  echo -e "  --san\t\tThe comma-separated Subject Alternative Names (SAN) for the certificate. Each name must be prefixed with DNS: or IP: (e.g., 'DNS:localhost,IP:127.0.0.1'). Default: same as CN."
  echo
  echo "Example: generate-self-signed-tls-cert.sh --cn foo.acme.aws --country US --state AZ --city Phoenix --org Gruntwork"
}

# Log to stderr, as we use stdout to return values from functions
function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty."
    print_usage
    exit 1
  fi
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v "$name") ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function create_self_signed_cert_for_app {
  local common_name
  local country
  local state
  local city
  local org
  local tls_certs_dir="$DEFAULT_TLS_CERTS_DIR"
  local expiration_days="$DEFAULT_EXPIRATION_DAYS"
  local key_size_bits="$DEFAULT_KEY_SIZE_BITS"
  local alternative_names="$DEFAULT_ALTERNATIVE_NAMES"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --cn)
        assert_not_empty "$key" "$2"
        common_name="$2"
        shift
        ;;
      --country)
        assert_not_empty "$key" "$2"
        country="$2"
        shift
        ;;
      --state)
        assert_not_empty "$key" "$2"
        state="$2"
        shift
        ;;
      --city)
        assert_not_empty "$key" "$2"
        city="$2"
        shift
        ;;
      --org)
        assert_not_empty "$key" "$2"
        org="$2"
        shift
        ;;
      --dir)
        assert_not_empty "$key" "$2"
        tls_certs_dir="$2"
        shift
        ;;
      --expiration)
        assert_not_empty "$key" "$2"
        expiration_days="$2"
        shift
        ;;
      --size)
        assert_not_empty "$key" "$2"
        key_size_bits="$2"
        shift
        ;;
      --san)
        assert_not_empty "$key" "$2"
        alternative_names="$2"
        shift
        ;;
      *)
        echo "ERROR: Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_is_installed "openssl"

  assert_not_empty "--cn" "$common_name"
  assert_not_empty "--country" "$country"
  assert_not_empty "--state" "$state"
  assert_not_empty "--city" "$city"
  assert_not_empty "--org" "$org"

  local -r ca_cert_path="$tls_certs_dir/CA.crt"
  local -r ca_key_path="$tls_certs_dir/CA.key"
  local -r ca_srl_path="$tls_certs_dir/CA.srl"
  local -r app_csr_path="$tls_certs_dir/app.csr"
  local -r app_cert_path="$tls_certs_dir/app.crt"
  local -r app_key_path="$tls_certs_dir/app.key"

  local san="DNS:$common_name"
  if [[ -n "$alternative_names" ]]; then
    san="$alternative_names"
  fi

  if [[ -f "$app_cert_path" || -f "$app_key_path" || -f "$ca_cert_path" ]]; then
    log_info "Self-signed TLS certs already exist at $app_cert_path, $app_key_path, and/or $ca_cert_path. Will not generate again."
    return
  fi

  log_info "Generating self-signed TLS certs..."

  # Create the folder for TLS certs if it doesn't exist
  mkdir -p "$tls_certs_dir"

  # OpenSSL requires this file to exist or you get an error: https://github.com/openssl/openssl/issues/7754
  touch ~/.rnd

  # Create the Certificate Authority (CA): generates CA.key and CA.crt
  # Note: we set a fake Common Name (CN), as it isn't checked anywhere for the CA, but the CN for the CA MUST be
  # different than the CN on the app certificate generated below (i.e., they can't both be localhost).
  # https://stackoverflow.com/a/23715832/483528
  openssl req \
      -new \
      -newkey \
      "rsa:$key_size_bits" \
      -days "$expiration_days" \
      -nodes \
      -x509 \
      -subj "/C=$country/ST=$state/L=$city/O=$org/CN=$common_name-CA" \
      -keyout "$ca_key_path" \
      -out "$ca_cert_path"

  # Create the Certificate Signing Request (CSR): generates app.key and app.csr
  openssl req \
    -new \
    -newkey \
    "rsa:$key_size_bits" \
    -nodes \
    -subj "/C=$country/ST=$state/L=$city/O=$org/CN=$common_name" \
    -keyout "$app_key_path" \
    -out "$app_csr_path"

  # Use the CA to sign the CSR: generates app.crt
  openssl x509 \
    -req \
    -in "$app_csr_path" \
    -CA "$ca_cert_path" \
    -CAkey "$ca_key_path" \
    -CAcreateserial \
    -days "$expiration_days" \
    -extfile <(printf "subjectAltName=$san\nbasicConstraints=critical,CA:false") \
    -out "$app_cert_path"

  # Now we delete the CA private key so it can never be used again. We also clean up the CA serial number and app CSR.
  rm -f "$ca_key_path"
  rm -f "$ca_srl_path"
  rm -f "$app_csr_path"

  # And now we set the permissions properly
  chmod 0600 "$ca_cert_path"
  chmod 0600 "$app_cert_path"
  chmod 0600 "$app_key_path"

  log_info "Self-signed TLS certs have been successfully generated at $app_cert_path, $app_key_path, and $ca_cert_path!"
}

create_self_signed_cert_for_app "$@"