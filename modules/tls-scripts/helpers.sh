#!/bin/bash
# A common set of Bash helper function used in these scripts. The idea is that you source this file to pull all the
# functions into your other scripts, rather than having to copy/paste them all over the place.

readonly this_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log to stderr, as everything in stdout will be used by boilerplate
function log {
  local -r msg="$@"
  >&2 echo -e "$msg"
}

# Assert that a given binary is installed on this box
function assert_is_installed {
  local -r name="$1"
  local -r message="$2"

  if [[ ! $(command -v ${name}) ]]; then
    log "ERROR: The binary '$name' is required by this script but is not installed or in the system's PATH."
    if [[ ! -z "$message" ]]; then
      log "$message"
    fi
    exit 1
  fi
}

# Assert that the given command-line arg is non-empty.
function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"
  local -r message="$3"

  if [[ -z "$arg_value" ]]; then
    log "ERROR: The value for '$arg_name' cannot be empty. $message"
    print_usage
    exit 1
  fi
}

function read_from_secrets_manager {
  local -r name="$1"
  local -r region="$2"

  local -r max_retries=3
  local -r time_between_retries_sec=3
  local secret_value

  for (( c=0; c<"$max_retries"; c++ )); do
    log "Looking up secret '$name' in AWS Secrets Manager."
    if secret_value=$(aws secretsmanager get-secret-value --region "$region" --secret-id "$name" --query "SecretString" --output "text"); then
      echo -n "$secret_value"
      return
    fi

    log "Did not find secret '$name' in AWS Secrets Manager. This may be due to eventual consistency. Will sleep for $time_between_retries_sec seconds and try again."
    sleep "$time_between_retries_sec"
  done

  log "Could not find secret '$name' in AWS Secrets Manager after $max_retries retries."
  exit 1
}

function store_in_secrets_manager {
  local -r password_name="$1"
  local -r password_description="$2"
  local -r password="$3"
  local -r aws_region="$4"

  local create_secret_response

  log "Creating secret '$password_name' in AWS Secrets Manager."
  create_secret_response=$(aws secretsmanager create-secret \
    --region "$aws_region" \
    --name "$password_name" \
    --description "$password_description" \
    --secret-string "$password")

  echo -n "$create_secret_response"
}

function import_certificate_to_acm {
  local -r cert_public_key_path="$1"
  local -r cert_private_key_path="$2"
  local -r ca_public_key_path="$3"
  local -r aws_region="$4"

  local cert_upload_output
  local cert_arn

  cert_upload_output=$(AWS_DEFAULT_REGION="$aws_region" aws acm import-certificate --certificate "fileb://${VAULT_TLS_MODULE_PATH}/$cert_public_key_path" --private-key "fileb://${VAULT_TLS_MODULE_PATH}/$cert_private_key_path" --certificate-chain "fileb://${VAULT_TLS_MODULE_PATH}/$ca_public_key_path")

  cert_arn=$(echo "$cert_upload_output" | jq '.CertificateArn')
  echo -n "$cert_arn"
}

function generate_password {
  local -r password_length="$1"
  log "Generating password for of length $password_length"
  pwgen -s "$password_length" 1
}

# Usage: join SEPARATOR ARRAY
#
# Joins the elements of ARRAY with the SEPARATOR character between them.
#
# Examples:
#
# join ", " ("A" "B" "C")
#   Returns: "A, B, C"
#
function join {
  local -r separator="$1"
  shift
  local -r values=("$@")

  printf "%s$separator" "${values[@]}" | sed "s/$separator$//"
}

function assume_iam_role {
  local -r iam_role_arn="$1"

  log "Assuming IAM role $iam_role_arn"

  local assume_role_response
  local access_key_id
  local secret_access_key
  local session_token

  assume_role_response=$(aws sts assume-role --role-arn "$iam_role_arn" --role-session-name "usage-patterns")

  access_key_id=$(echo "$assume_role_response" | jq -r '.Credentials.AccessKeyId')
  secret_access_key=$(echo "$assume_role_response" | jq -r '.Credentials.SecretAccessKey')
  session_token=$(echo "$assume_role_response" | jq -r '.Credentials.SessionToken')

  export AWS_ACCESS_KEY_ID="$access_key_id"
  export AWS_SECRET_ACCESS_KEY="$secret_access_key"
  export AWS_SESSION_TOKEN="$session_token"
}
