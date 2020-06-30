#!/bin/bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

instance_ipv4="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"
instance_id="$(curl http://169.254.169.254/latest/meta-data/instance-id)"
service_id="${service_id}"
echo "Registering $instance_ipv4 to service $service_id as $instance_id"

aws servicediscovery register-instance \
  --region ${aws_region} \
  --service-id  "$service_id" \
  --instance-id "$instance_id" \
  --attributes AWS_INSTANCE_IPV4="$instance_ipv4"
