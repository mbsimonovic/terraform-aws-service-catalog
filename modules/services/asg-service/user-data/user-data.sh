#!/bin/bash
#
# A script run in User Data that can be used to configure each EC2 Instance in the ASG. It runs the initialization
# script specified by the user.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# The variables in the code below should be filled in by Terraform interpolation
"${init_script_path}" \
  --aws-region "${aws_region}" \
  --vpc-name "${vpc_name}" \
  --asg-name "${asg_name}" \
  --port "${server_port}"
  {{- if .IncludeDatabaseUrl }} \
  --db-url "${db_url}"
  {{- end }}
  {{- if .IncludeRedisUrl }} \
  --redis-url "${redis_url}"
  {{- end }}
  {{- if .IncludeMemcachedUrl }} \
  --memcached-url "${memcached_url}"
  {{- end }}
  {{- if .IncludeMongoDbUrl }} \
  --mongo-url "${mongo_url}"
  {{- end }}
  {{- if .IncludeInternalAlbUrl }} \
  --internal-alb-url "${internal_alb_url}" \
  --internal-alb-port "${internal_alb_port}"
  {{- end }}



