#!/bin/bash
#
# This script is meant to be run in the User Data of each EKS instance. This does the following:
#
# 1. Register the instance with the EKS cluster control plane.
# 1. Set node labels that map to the EC2 tags associated with the instance.
#
# Note, this script:
#
# 1. Assumes it is running in the AMI built from the eks-node-al2.json Packer template.
# 2. Has a number of variables filled in using Terraform interpolation.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Include common functions
source /etc/user-data/user-data-common.sh

function configure_eks_instance {
  local -r aws_region="$1"
  local -r eks_cluster_name="$2"
  local -r eks_endpoint="$3"
  local -r eks_certificate_authority="$4"

  local -r node_labels="$(map-ec2-tags-to-node-labels)"

  start_fail2ban

  local max_pods=""
  %{ if max_pods_allowed != null }
  max_pods="${max_pods_allowed}"
  %{ else }
    %{ if use_prefix_mode_to_calculate_max_pods }
  max_pods="$(/etc/eks/max-pods-calculator.sh --instance-type-from-imds --cni-version 1.9.0-eksbuild.1 --cni-prefix-delegation-enabled)"
    %{ endif }
  %{ endif }

  local kubelet_extra_args="--node-labels=\"$node_labels\""
  if [[ -n "$max_pods" ]]; then
    kubelet_extra_args+=" --max-pods=$max_pods"
  fi
  kubelet_extra_args+=" ${eks_kubelet_extra_args}"

  local -a bootstrap_args=( \
    --apiserver-endpoint "$eks_endpoint" \
    --b64-cluster-ca "$eks_certificate_authority" \
    --kubelet-extra-args "$kubelet_extra_args" \
  )
  if [[ -n "$max_pods" ]]; then
    # NOTE: The max_pods setting logic may be contradictory, but is correct. The bootstrap.sh script has a routine to
    # automatically calculate the max pods for the node based on non prefix delegated ENI IP address availability. When
    # setting the max pods setting directly or with CNI prefix delegation, we need to disable this routine, but also
    # configure the max pods setting directly on the kubelet. Hence, we disable the automatic routine in the
    # bootstrap.sh script by passing in --use-max-pods false, and then configure the kubelet extra args to set the max
    # pods on the kubelet directly.
    bootstrap_args+=( --use-max-pods false )
  fi
  bootstrap_args+=( ${eks_bootstrap_script_options} "$eks_cluster_name" )

  echo "Running eks bootstrap script to register instance to cluster"
  /etc/eks/bootstrap.sh "$${bootstrap_args[@]}"
}

start_ec2_baseline \
  "${enable_cloudwatch_log_aggregation}" \
  "${enable_ssh_grunt}" \
  "${enable_fail2ban}" \
  "${enable_ip_lockdown}" \
  "${ssh_grunt_iam_group}" \
  "${ssh_grunt_iam_group_sudo}" \
  "${log_group_name}" \
  "${external_account_ssh_grunt_role_arn}"

configure_eks_instance \
  "${aws_region}" \
  "${eks_cluster_name}" \
  "${eks_endpoint}" \
  "${eks_certificate_authority}"
