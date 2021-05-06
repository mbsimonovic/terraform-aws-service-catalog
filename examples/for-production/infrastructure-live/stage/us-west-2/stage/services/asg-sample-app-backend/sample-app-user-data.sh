#!/usr/bin/env bash
# This script is meant to run as part of EC2 Instance User Data to start the aws-sample-app while the EC2 Instance is
# booting. The variables wrapped with a dollar sign and curly braces are filled in using Terraform interpolation.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly APP_USER="app"
readonly APP_PATH="/opt/aws-sample-app"


# Include common functions from the common User Data script installed from the ec2-baseline module
source /etc/user-data/user-data-common.sh

# Include functions from the ec2-helpers.sh script in the aws-sample-app repoo
source "$APP_PATH/bin/ec2-helpers.sh"

# We will create a tmpfs volume at this path and use it to store secrets. Since tmpfs is in-memory only, this makes
# it a good place to store secrets.
readonly SECRETS_DIR="/mnt/secrets"

# Use systemd to start the app and ensure it keeps running even if it crashes or there is a reboot.
function start_sample_app {
  local -r app_name="$1" # The name of the app. Should be "frontend" or "backend".
  local -r app_path="$2" # The folder where the app code is installed (e.g., /opt/aws-sample-app).
  local -r app_user="$3" # The OS user who will run the app.
  local -r environment_name="$4" # The name of the current environment (e.g., "stage").
  local -r secrets_dir="$5" # The folder where secrets are stored. Should be a tmpfs mount.
  local -r secrets_manager_region="$6" # The region from which to read Secrets Manager secrets.
  local -r db_config_secrets_manager_arn="$7" # The ARN of the secret containing the database configuration
  local -r tls_config_secrets_manager_arn="$8" # The ARN of the secret containing the TLS configuration

  local -r systemd_unit_name="aws-sample-app-$app_name"
  local -r systemd_unit_path="$SYSTEMD_UNIT_BASE_DIR/$systemd_unit_name.service"

  echo "Adding systemd unit in '$systemd_unit_path' to run app '$app_name' in '$app_path' with user '$app_user'"
  tee "$systemd_unit_path" > /dev/null <<EOF
[Unit]
Description=Gruntwork AWS Sample App
After=syslog.target
After=network.target
[Service]
WorkingDirectory=$app_path
ExecStart=/usr/bin/npm start
Restart=on-failure
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$systemd_unit_name
Type=simple
User=$app_user
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=60
# We must set these values as environment variables so they are accessible bin/run-app.sh
Environment="CONFIG_APP_NAME=$app_name"
Environment="CONFIG_APP_ENVIRONMENT_NAME=$environment_name"
Environment="CONFIG_SECRETS_DIR=$secrets_dir"
Environment="CONFIG_SECRETS_SECRETS_MANAGER_REGION=$secrets_manager_region"
Environment="CONFIG_SECRETS_SECRETS_MANAGER_DB_ID=$db_config_secrets_manager_arn"
Environment="CONFIG_SECRETS_SECRETS_MANAGER_TLS_ID=$tls_config_secrets_manager_arn"
[Install]
WantedBy=multi-user.target
EOF

  echo "Using systemd to start app"
  sudo systemctl enable "$systemd_unit_name"
  sudo systemctl start "$systemd_unit_name"
}

# Mount a tmpfs volume for secrets
mount_tmpfs_volume "$SECRETS_DIR" "$APP_USER"
chmod 0700 "$SECRETS_DIR"

# Write a config file with the settings for this environment
write_app_config_file \
  "${app_name}" \
  "$APP_PATH" \
  "$APP_USER" \
  "${environment_name}" \
  "$SECRETS_DIR" \
  "${http_port}" \
  "${https_port}" \
  "${secrets_manager_config}" \
  "${database_config}" \
  "${cache_config}" \
  "${services_config}"

# Use systemd to start the app
start_sample_app \
  "${app_name}" \
  "$APP_PATH" \
  "$APP_USER" \
  "${environment_name}" \
  "$SECRETS_DIR" \
  "${secrets_manager_region}" \
  "${db_config_secrets_manager_arn}" \
  "${tls_config_secrets_manager_arn}"
