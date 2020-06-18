#!/bin/bash
#
# A script run in User Data that can be used to configure each EC2 Instance in the ASG. It runs the initialization
# script specified by the user.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

