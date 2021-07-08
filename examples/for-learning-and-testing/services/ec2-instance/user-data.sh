#!/bin/bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/custom-user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Hello, World" > /mnt/demo/demo-file.txt
