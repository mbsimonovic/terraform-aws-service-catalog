# OpenVPN Server Example

This is an example of how to use the [OpenVPN server module](/modules/mgmt/openvpn-server) to AWS. This example is optimized for learning, experimenting, and testing, but not direct production usage. If you want to deploy this module directly in production, check out the [examples/for-production folder](/examples/for-production).



## Deploy instructions

To deploy an OpenVPN server , you need to:

1. [Build the AMI using Packer](#build-the-ami-using-packer)
1. [Deploy the AMI using Terraform](#deploy-the-ami-using-terraform)


### Build the AMI using Packer

1. Install [Packer](https://packer.io/)
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Create a [GitHub personal access
   token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line)
   with `repo` permissions and set it as the environment variable `GITHUB_OAUTH_TOKEN`: e.g.,
   `export GITHUB_OAUTH_TOKEN=xxx`.   
1. Find the version of the Gruntwork AWS Service Catalog you want to use by looking at the [releases
   page](/../../releases).
1. Run the build:

    ```bash
    packer build \
      -var aws_region="<AWS REGION YOU WANT TO USE>" \
      -var service_catalog_ref="<SERVICE CATALOG VERSION YOU WANT TO USE>" \
      -var version_tag="<VERSION TAG FOR AMI>" \
      modules/mgmt/openvpn-server/openvpn-server.json
    ```

    See also the `variables` block in [openvpn-server.json](/modules/mgmt/openvpn-server/openvpn-server.json) for other
    variables you can set.
1. When the build finishes, it'll output the ID of the AMI:

    ```
    --> amazon-ebs: AMIs were created:
    us-east-1: ami-abcd1234efgh5678
    ```


### Deploy the AMI using Terraform

1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override). In
   particular, be sure to set `ami_id` to the ID of the AMI you just built, and make sure `aws_region` matches the
   region in which you built that AMI. We recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for
   all the ways you can set Terraform variables).
1. Run `terraform init`.
1. Run `terraform apply`.
1. The module will output the host name for your OpenVPN server. You should be able to SSH to the instance.
1. When you're done testing, to undeploy everything, run `terraform destroy`.    

## OpenVPN access

Once you have requested and received an OpenVPN Client Configuration (`.ovpn`) file using the
[openvpn-admin](https://github.com/gruntwork-io/package-openvpn/blob/master/examples/openvpn-host/README.md) tool, you can import that into any supported OpenVPN client.

Once connected to the VPN, your traffic is encrypted and "tunneled" and you are effectively connected to the remote network. You can then connect to any other EC2 instance or service in the account, including those in the private subnets of the VPC. To access other resources on the network, such as RDS database instances, you may need to permit access from the VPN server to the remote security group.

For further information, refer to the [OpenVPN server module](/modules/mgmt/openvpn-server) documentation.

## Known Limitations

When you first run the OpenVPN server it will take a long time, often 10 minutues or more until the first-time initialization of the public key infrastructure (PKI) necessary for running OpenVPN has initialized. You can tell that this process is complete once the `/etc/openvpn/openvpn-init-complete` file has been created.
