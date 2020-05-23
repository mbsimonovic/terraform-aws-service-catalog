# Deploying the Reference Architecture from scratch

In the previous section, you saw how to [undeploy parts or all of the Reference Architecture](06-undeploy.md). In this
section, we'll show you how to deploy the entire Reference Architecture, or one of the environments in the
Reference Architecture (e.g., stage or prod), from scratch. This is useful if you want to know how to quickly set up
and tear down environments.

1. [Deployment Order](#deployment-order)
1. [Build AMIs](#build-amis)
1. [Build Docker images](#build-docker-images)
1. [Create EC2 Key Pairs](#create-ec2-key-pairs)
1. [Configure Terraform backends](#configure-terraform-backends)
1. [Configure the VPN server](#configure-the-vpn-server)
1. [Create data store passwords](#create-data-store-passwords)
1. [Import Route 53 hosted zones](#import-route-53-hosted-zones)
1. [Create TLS certs](#create-tls-certs)
1. [Create an IAM User for KMS](#create-an-iam-user-for-kms)
1. [Run Terragrunt](#run-terragrunt)




## Deployment Order

If you are deploying the entire Reference Architecture from scratch, then you should be aware of the various
dependencies that exist between the accounts. In order to ensure that all the dependent resources exist, we recommend
deploying the accounts in the following order:

1. `security`
1. `shared-services`
1. `dev`, `stage`, and `prod`. These can be done in parallel.




## Build AMIs

All the EC2 Instances in the Reference Architecture (e.g., the EKS Cluster instances, the OpenVPN server, etc) run
[Amazon Machine Images (AMIs)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) that are defined as code
using [Packer](https://www.packer.io/). To build these AMIs:

1. **Find the Packer templates**. You will find the Packer templates (`.json` files) in the [Gruntwork Service 
   Catalog](https://github.com/gruntwork-io/aws-service-catalog/), plus any custom Packer templates you
   created in your own Service Catalog.
   
1. **Create a VPC for building AMIs**. All the AMIs are built using an EC2 instance that is temporarily deployed into a 
  VPC of the account and region that owns the AMI. This selection of the VPC and Subnet is done using the tags 
  `gruntwork.io/allow-packer=true`. You need to ensure a VPC with a Public Subnet, created with the tag exists in the 
  target region of the AMI account owner. The easiest way to do this would be to deploy a VPC using the 
  `networking/vpc-app` service in the target region. This service will properly tag the public subnets and the VPC for 
  use with packer.
    
1. **Run Packer**. Follow the [How to build machine images using Packer templates from the Service 
   Catalog](https://github.com/gruntwork-io/aws-service-catalog/blob/master/core-concepts.md#deploy-new-infrastructure)
   docs to build AMIs from these Packer templates. Pay special attention to the instructions on filling in variables,
   especially for the following variables:
    
    * `aws_region`: The AWS region you want to use.
    * `copy_to_regions`: Share the AMI with other regions.
    * `ami_users`: The IDs of AWS accounts with which to share the built AMI.
    * `encrypt_boot`: Encrypt the root volume. If you set this to `true`, you _cannot_ share the AMI via `ami_users`.
      You must instead build the AMI separately in each AWS account.

1. **Fill in AMI IDs**. Once the builds are completed, you will need to fill in the resulting AMI IDs in the 
   corresponding `terragrunt.hcl` files.




## Build Docker images

If you're using Docker, the sample apps in the Reference Architecture will try to deploy Docker images. You will need
to:

1. Build the Docker images.
1. Tag them with a version number of some sort.
1. Push the images to your Docker Registry (typically [ECR](https://aws.amazon.com/ecr/))
1. Fill in the Docker image name and version number in the `terragrunt.hcl` files.

See the [deploying your apps docs](03-deploy-apps.md) for instructions on building, tagging, and pushing Docker images.




## Create EC2 Key Pairs

The Reference Architecture installs [ssh-grunt](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt)
on every EC2 Instance so that each developer can use their own username and key to SSH to servers. However, we still 
recommend associating an [EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) with 
your EC2 Instances as an emergency backup, in case their is some sort of issue with `ssh-grunt`.

We typically recommend creating at least 2 Key Pairs:

1. One for the OpenVPN server.
1. One for all other services.

To create an EC2 Key Pair:

1. Go to the [Key Pair section](https://console.aws.amazon.com/ec2/v2/home#KeyPairs:sort=keyName) of the EC2 Console.
1. Click "Create Key Pair."
1. Enter a name for the Key Pair.
1. Save the Key Pair to disk. Do NOT share this Key Pair with anyone else; it's only for emergency backup!
1. Add a passphrase to the Key Pair: `ssh-keygen -p -f <KEY_PAIR_PATH>`.
1. Change permissions on the Key Pair: `chmod 400 <KEY_PAIR_PATH>`.
1. Pass the Key Pair name to the appropriate parameter in `terragrunt.hcl`; typically, this parameter will be called 
   `ssh_key_name`, `keypair_name`, or `cluster_instance_keypair_name`. Ensure you only use the OpenVPN keypair for the 
   OpenVPN server.




## Configure Terraform backends

The Reference Architecture uses an [S3 backend](https://www.terraform.io/docs/backends/types/s3.html) to store
[Terraform State](https://www.terraform.io/docs/state/). We also use DynamoDB for locking. We recommend storing the
Terraform State for each AWS account in a separate S3 bucket and DynamoDB table. You will need to fill in the name and
region of the S3 bucket and DynamoDB table in the root `terragrunt.hcl` file in `infrastructure-live`. 

When you run Terragrunt, if the S3 bucket or DynamoDB table don't already exist, they will be created automatically.




## Configure the VPN server

The Reference Architecture includes an [OpenVPN server](https://openvpn.net/). The very first time you deploy the
server, it will create the [Public Key Infrastructure (PKI)](https://en.wikipedia.org/wiki/Public_key_infrastructure) 
it will use to sign certificates. This process is very CPU intensive and, on `micro` EC2 Instances, it can take *hours*, 
as it seems to exceed the burst balance almost immediately.

To avoid this, we recommend initially deploying the OpenVPN server with a larger instance (`t3.medium` can generate the
PKI in 1-2 minutes). Once the PKI has been generated, you can downgrade to a smaller instance again to save money.




## Create data store passwords

Some of the data stores used in the Reference Architecture, such as [RDS databases](https://aws.amazon.com/rds/),
require that you set a password in the Terraform code. We do NOT recommend putting that password, in plaintext,
directly in the code. Instead, we recommend:

1. Create a long, strong, random password. Preferably 30+ characters.
1. Store the password in a secure secrets manager.
1. Every time you go to deploy the data store, set the password as an environment variable that Terraform can find
   (see [Terraform environment variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables)).
   For example, for RDS DBs, you typically set the `TF_VAR_master_password` environment variable:

    ```bash
    export TF_VAR_master_password=xxx
    ```




## Import Route 53 hosted zones

The Reference Architecture configures DNS entries using [Route 53](https://aws.amazon.com/route53/). Each domain name
will live in a [Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/AboutHZWorkingWith.html)
that is either created automatically if you bought a domain name through Route 53, or manually if you are using Route
53 to manage DNS for a domain name bought externally.

If the Public Hosted Zone already exists—which it usually does if you bought or configured the domain in the Route 53
web UI—you will need to use the [`import` command](https://www.terraform.io/docs/import/index.html) to put it under 
Terraform control. Go to the `route53-public` module in `infrastructure-live` for the account you're deploying and run:

```bash
terragrunt import aws_route53_zone.public_zones[<DOMAIN_NAME>] <HOSTED_ZONE_ID>
```

Where `DOMAIN_NAME` is the domain name (e.g., `example.com`) and `HOSTED_ZONE_ID` is the primary ID of the Hosted 
Zone for the domain, which you can find in the AWS Route 53 Console (it typically looks something like 
`Z1AB1Z2CDE3FG4`).




## Create an IAM User for KMS

The Reference Architecture uses [KMS](https://aws.amazon.com/kms/) to encrypt and decrypt secrets. When you create a
new [Customer Master Key (CMK)](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html) in KMS, you must
assign at least one IAM User as an "administrator" for the CMK. If there are no admins, then the CMK—and any secrets
encrypted with it—may become completely inaccessible!

Therefore, you will need to create an IAM User in the security account, as documented in [Setting up initial 
access](02-authenticate.md#setting-up-initial-access).




## Create TLS certs


### Public-facing TLS certs

The Reference Architecture will automatically request and validate TLS certs for your domain names using [AWS 
Certificate Manager (ACM)](https://aws.amazon.com/certificate-manager/). No manual process is required here.


### Self-signed TLS certs for your apps

*(Documentation coming soon. If you need help with this ASAP, please contact [support@gruntwork.io](mailto:support@gruntwork.io).)*


### Self-signed TLS certs for your internal load balancers

*(Documentation coming soon. If you need help with this ASAP, please contact [support@gruntwork.io](mailto:support@gruntwork.io).)*





## Run Terragrunt

Now that you have all the prerequisites out of the way, you can finally use Terragrunt to deploy everything!


### Authenticate

If you're creating a  totally new AWS account, the easiest way to do the initial deployment is to [create a temporary IAM
User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) in that account with admin access. Create
[Access Keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) for that IAM User and
set them as environment variables:

```bash
export AWS_ACCESS_KEY_ID=(your access key for this account)
export AWS_SECRET_ACCESS_KEY=(your secret key for this account)
```

Once everything is deployed, you can delete this IAM user, and access the account via IAM roles (see the
[cross-account-iam-access module](https://github.com/gruntwork-io/module-security/tree/master/modules/cross-account-iam-roles)
for details).




### Run apply-all

To deploy the entire account in a single command, you can use `apply-all`. For example, to deploy the stage account:

```bash
cd stage
terragrunt apply-all
```

You may want to run Terragrunt with the `--terragrunt-non-interactive` flag to avoid any interactive prompts:

```bash
terragrunt apply-all \
  --terragrunt-non-interactive
```

If you want to deploy just a single module at a time, just use `terragrunt apply`:

```bash
cd stage/eu-west-1/stage/services/eks-cluster
terragrunt apply
```


### Deployment order

* **Dependencies between AWS accounts**. Note that, in general, there are no dependencies between different AWS accounts, 
  so you can deploy them in any order. The only exception to this is the `security` account. This account defines all 
  IAM Users, Groups, and the S3 bucket used for CloudTrail audit logs, so it must always be deployed first.

* **Dependencies within AWS accounts**. Within an AWS account, there are many deployment dependencies (e.g., almost 
  everything depends on the VPC being deployed first), all of which should be defined in the `dependency` and
  `dependencies` blocks of `terragrunt.hcl` files. Terragrunt takes these dependencies into account when you run
  `apply-all`, so it should automatically deploy everything in the right order.




### Expected errors

Due to bugs in Terraform, you will most likely hit some of the following (harmless) errors:

1. TLS handshake timeouts downloading Terraform providers or remote state. See
   https://github.com/hashicorp/terraform/issues/15817.

1. "A separate request to update this alarm is in progress". See
   https://github.com/terraform-providers/terraform-provider-aws/issues/422.

1. "Error loading modules: module xxx: not found, may need to run 'terraform init'". This typically happens if you
   run `apply-all`, change the version of a module you're using, and run `apply-all` again. Unfortunately, Terragrunt
   is not yet smart enough to automatically download the updated module (see
   https://github.com/gruntwork-io/terragrunt/issues/388). Easiest workaround for now is to set
   `TERRAGRUNT_SOURCE_UPDATE=true` to force Terragrunt to redownload everything:

    ```bash
    TERRAGRUNT_SOURCE_UPDATE=true terragrunt apply-all
    ```

If you hit any of these issues—and you'll almost certainly hit one of the first two—simply re-run `apply-all` and they
should go away.


