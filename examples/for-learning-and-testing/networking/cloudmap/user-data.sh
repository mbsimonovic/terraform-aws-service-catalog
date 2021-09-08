#!/bin/bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# The AWS EC2 Instance Metadata endpoint
readonly metadata_endpoint="http://169.254.169.254/latest"
# The AWS EC2 Instance identity document endpoint
readonly instance_identity_endpoint="http://169.254.169.254/latest/dynamic/instance-identity/document"
# A convenience variable representing 3 hours, for use in requesting a token from the IMDSv2 endpoint
readonly three_hours_in_s=10800
# This function calls the Instance Metadata Service endpoint version 2 (IMDSv2) which is hardened against certain attack vectors.
# The endpoint returns a token that must be supplied on subsequent requests. This implementation fetches a new token
# for each transaction. See:
# https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/
# for more information
function ec2_metadata_http_get {
  local -r path="$1"
  token=$(ec2_metadata_http_put $three_hours_in_s)
  curl "$metadata_endpoint/meta-data/$path" -H "X-aws-ec2-metadata-token: $token" \
    --silent --location --fail --show-error
}

function ec2_metadata_http_put {
  # We allow callers to configure the ttl - if not provided it will default to 6 hours
  local ttl="$1"
  if [[ -z "$1" ]]; then
    ttl=21600
  elif [[ "$1" -gt 21600 ]]; then
    ttl=21600
  fi
  token=$(curl --silent --location --fail --show-error -X PUT "$metadata_endpoint/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: $ttl")
  echo "$token"
}

instance_ipv4=$(ec2_metadata_http_get "public-ipv4")
instance_id=$(ec2_metadata_http_get "instance-id")
service_id="${service_id}"
echo "Registering $instance_ipv4 to service $service_id as $instance_id"

aws servicediscovery register-instance \
  --region ${aws_region} \
  --service-id "$service_id" \
  --instance-id "$instance_id" \
  --attributes AWS_INSTANCE_IPV4="$instance_ipv4"
