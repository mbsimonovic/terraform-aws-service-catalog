# This script contains common utility functions for initializing EC2 instances at boot time

function file_contains_text {
  local -r text="$1"
  local -r file="$2"
  grep -q "$text" "$file"
}

function file_exists {
  local -r file="$1"
  [[ -f "$file" ]]
}

function append_text_in_file {
  local -r text="$1"
  local -r file="$2"

  echo -e "$text" | sudo tee -a "$file"
}

# Replace a line of text in a file. Only works for single-line replacements.
function replace_text_in_file {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"

  sudo sed -i "s|$original_text_regex|$replacement_text|" "$file"
}

function replace_or_append_in_file {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"

  if $(file_exists "$file") && $(file_contains_text "$original_text_regex" "$file"); then
    replace_text_in_file "$original_text_regex" "$replacement_text" "$file"
  else
    append_text_in_file "$replacement_text" "$file"
  fi
}

function attach_volume {
  local -r aws_region="$1"
  local -r volume_name_tag="$2"
  local -r device_name="$3"
  local -r mount_point="$4"
  local -r owner="$5"

  mount-ebs-volume \
    --aws-region "$aws_region" \
    --volume-with-same-tag "$volume_name_tag" \
    --device-name "$device_name" \
    --mount-point "$mount_point" \
    --owner "$owner"
}

function start_cloudwatch_logs_agent {
  local -r log_group_name="$2"

  echo "Starting CloudWatch Logs Agent in VPC"
  /etc/user-data/cloudwatch-log-aggregation/run-cloudwatch-logs-agent.sh --log-group-name "$log_group_name"
}

function start_ssh_grunt {
  local -r ssh_grunt_iam_group="$1"
  local -r ssh_grunt_iam_group_sudo="$2"
  local -r external_account_ssh_grunt_role_arn="$3"

  echo "Starting ssh-grunt"

  local args=()

  if [[ -n "$ssh_grunt_iam_group" ]]; then
    args+=("--iam-group" "$ssh_grunt_iam_group")
  fi

  if [[ -n "$ssh_grunt_iam_group_sudo" ]]; then
    args+=("--iam-group-sudo" "$ssh_grunt_iam_group_sudo")
  fi

  if [[ -n "$$external_account_ssh_grunt_role_arn" ]]; then
    args+=("--role-arn" "$$external_account_ssh_grunt_role_arn")
  fi

  # Call 'sync-users' to sync IAM users the first time during boot. Call 'install' to add a CRON job that will re-run
  # 'sync-users' on a schedule. Note that we need double dollar signs as Terraform will try to interpolate a single
  # dollar sign followed by curly braces
  sudo /usr/local/bin/ssh-grunt iam sync-users "$${args[@]}"
  sudo /usr/local/bin/ssh-grunt iam install "$${args[@]}"
}

function start_fail2ban {
  echo "Starting fail2ban"
  /etc/user-data/configure-fail2ban-cloudwatch/configure-fail2ban-cloudwatch.sh --cloudwatch-namespace Fail2Ban
}

function start_instance_features {
  local -r enable_cloudwatch_log_aggregation="$1"
  local -r enable_ssh_grunt="$2"
  local -r enable_fail2ban="$3"
  local -r enable_ip_lockdown="$4"
  local -r ssh_grunt_iam_group="$5"
  local -r ssh_grunt_iam_group_sudo="$6"
  local -r log_group_name="$7"
  local -r external_account_ssh_grunt_role_arn="$8"

  if [[ "$enable_cloudwatch_log_aggregation" == "true" ]]; then
    start_cloudwatch_logs_agent "$log_group_name"
  fi

  if [[ "$enable_ssh_grunt" == "true" ]]; then
    start_ssh_grunt "$ssh_grunt_iam_group" "$ssh_grunt_iam_group_sudo" "$external_account_ssh_grunt_role_arn"
  fi

  if [[ "$enable_fail2ban" = "true" ]]; then
    start_fail2ban
  fi

  if [[ "$enable_ip_lockdown" = "true" ]]; then
    # Lock down the EC2 metadata endpoint so only the root and default users can access it
    /usr/local/bin/ip-lockdown 169.254.169.254 root ubuntu
  fi
}
