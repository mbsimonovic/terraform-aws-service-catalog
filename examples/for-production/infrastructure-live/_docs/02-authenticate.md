# Authentication

In the last section, you got a basic [overview of the architecture](01-overview.md), including learning that there is
a variety of infrastructure deployed across multiple AWS accounts. In this section, you'll learn about authenticating 
and connecting to all the resources in your AWS accounts:

* [Set up initial access](#setting-up-initial-access): If this is your first time using this infrastructure—that is, 
  if Gruntwork just deployed and handed over the Reference Architecture to you—go through this section first!  

* [Authenticate to the AWS Web Console](#authenticate-to-the-aws-web-console): Learn how to access each of your AWS 
  accounts using a web browser. Since all the infrastructure is managed as code, you shouldn't be making many changes 
  from the web console, but it's still useful for debugging, troubleshooting, learning, and looking at metrics, and logs.
  
* [Authenticate to AWS via the CLI](#authenticate-to-aws-via-the-cli): Learn how to access each of your AWS accounts 
  from the command line. You'll need this to work with CLI tools such as the `aws`, `terraform`, `terragrunt`, and 
  `packer`.
  
* [Authenticate to the VPN server](#authenticate-to-the-vpn-server): Just about all of the infrastructure is deployed 
  in private subnets, so it is not accessible directly from the public Internet. To be able to SSH to an EC2 instance
  or connect to a database, you'll first need to get "inside" the networking by connecting to the VPN server. 

* [Authenticate to EC2 Instances via SSH](#authenticate-to-ec2-instances-via-ssh): If you need to debug something on
  an EC2 instance, you'll need to connect over SSH. 

* [Authenticate to Kubernetes and Helm](#authenticate-to-kubernetes-and-helm): If you need to make changes in your
  Kubernetes cluster, you'll need to be able to connect and authenticate to the Kubernetes API server. You'll need this
  to work with CLI tools such as `kubectl` and `helm`. 




## Setting up initial access

If this is the first time you're using this infrastructure—that is, if the Gruntwork team just deployed a [Reference
Architecture](https://gruntwork.io/reference-architecture/) for you, and handed it over—this section will walk you 
through the initial setup steps:

1. [Configure root users](#configure-root-users)
1. [Configure your IAM user](#configure-your-iam-user)
1. [Configure other IAM users](#configure-other-iam-users)


### Configure root users

Each of your AWS accounts has a [root user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html) that
you need to configure. When you created the child AWS accounts(dev, stage, prod, etc), you provided the root user's
email address for each account; if you don't know what those email addresses were, you can login to the root (AKA 
master) account (the parent of the AWS Organization) and go to the [AWS Organizations 
Console](https://console.aws.amazon.com/organizations/home) to find the email addresses.

Once you have the email addresses, you'll need the passwords. Oddly, when you create child accounts in an AWS 
organization, AWS does _not_ allow you to set those passwords. So, to get the passwords, you will need to:

1. Go to the [AWS Console](https://console.aws.amazon.com/console/home).
1. If you are already signed in to some other AWS account, sign out, and return to the [AWS 
   Console](https://console.aws.amazon.com/console/home) again. 
1. If you had previously signed into some other AWS account as an IAM user, rather than a root user, click "Sign-in 
   using root account credentials."
1. Enter the email address of the root user.
1. Click "Forgot your password" to reset the password.
1. Check the email address associated with the root user account for a link you can use to create a new password.

Please note that the root user account can do just about *anything* in your AWS account, bypassing almost all security
restrictions you put in place, so you need to take extra care with protecting this account. We **very strongly**
recommend that when you reset the password for each account, you:

1. **Use a strong password**: preferably 30+ characters, randomly generated, and stored in a secrets manager.
1. **Enable Multi-Factor Auth (MFA)**: [Follow these instructions to enable 
   MFA](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html#enable-virt-mfa-for-root)
   for the root user. It takes less than a minute and _dramatically_ improves your security posture.
1. **Do not use the root user anymore**. After this initial set up, you should NOT use the root user account afterwords, 
   except in very rare circumstances. (e.g., if you get locked out of your IAM User account). For almost all day to day 
   tasks, you should use an IAM user instead, as described in the next section.

Please note that you'll want to repeat the process above of resetting the password and enablilng MFA for _every_ 
account in your organization: dev, stage, prod, shared-services, security, and the root/master account too!


### Configure your IAM user

All IAM users are defined and managed in the security account. As part of deploying a Reference Architecture for you, 
Gruntwork will create an IAM user with admin permissions in the security account and send you the credentials, 
encrypted via [Keybase](https://keybase.io/) (if for some reason this didn't happen, please email us at 
[support@gruntwork.io](mailto:support@gruntwork.io)). To decrypt the credentials, run:

```bash
keybase decrypt -m "<CIPHERTEXT SENT BY GRUNTWORK>"
```

The decrypted text will include:

1. **Login URL**. This should be of the format `https://<ACCOUNT ID>.signin.aws.amazon.com/console`.
1. **Username**. This is typically your email address.
1. **Password**. A randomly generated password that you'll have to reset.

Open the login URL in the browser and do the following:

1. **Reset your password as instructed**. Use a strong password: preferably 30+ characters, randomly generated, and 
   stored in a secrets manager.

1. **Enable MFA**. [Follow these instructions to enable 
   MFA](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable.html) for your IAM user. It takes 
   less than a minute and _dramatically_ improves your security posture. Moreover, MFA is **required** by the Reference
   Architecture, and you won't be able to access any other accounts without it!

1. **Logout and log back in**. After enabling MFA, you need to log out and then log back in, thereby forcing AWS to 
   prompt you for an MFA token. Until you don't do this, you will not be able to access anything else in the web 
   console! 

1. **Create access keys**. [Follow these instructions to create access 
   keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) for yourself. Store the
   access keys in a secrets manager. You will need these to authenticate to AWS from the command-line.        


### Configure other IAM users

Now that your IAM user is all set up, you can configure IAM users for the rest of your team! All of the IAM users are
managed as code in the security account, in the [account-baseline-app module](../security/_global/account-baseline). If
you open the `terragrunt.hcl` file in that repo, you should see the list of users, which will look something like:

```hcl
inputs = {
  users = {
    "jane@acme.com" = {
      groups               = ["full-access"]
      pgp_key              = "keybase:jane_on_keybase"
      create_login_profile = true
      create_access_keys   = false
    }
  }
}
``` 

Here's how you could two other users, Alice and Bob, to this list:

```hcl

inputs = {
  users = {
    "jane@acme.com" = {
      groups               = ["full-access"]
      pgp_key              = "keybase:jane_on_keybase"
      create_login_profile = true
    }
    
    "alice@acme.com" = {
      groups               = ["_account.dev-full-access", "_account.stage-full-access", "_account.prod-full-access"]
      pgp_key              = "keybase:alice_on_keybase"
      create_login_profile = true
    }

    "bob@acme.com" = {
      groups               = ["_account.prod-read-only", "ssh-grunt-sudo-users"]
      pgp_key              = "keybase:bob_on_keybase"
      create_login_profile = true
    }
  }
}
```

A few notes about the code above:

1. **Groups**. We add each user to a set of IAM groups: for example, we add Alice to IAM groups that give her admin
   access in the dev, stage, and prod accounts, whereas Bob gets read-only access to prod, plus SSH access (with sudo
   permissions) to EC2 instances. For the full list of IAM groups available out of the box, see the 
   [IAM groups module](https://github.com/gruntwork-io/module-security/tree/master/modules/iam-groups#iam-groups).
   
1. **PGP Keys**. We specify a PGP Key to use to encrypt any secrets for that user. Keys of the form `keybase:<username>` 
   are automatically fetched for user `<username>` on [Keybase](https://keybase.io/).
         
1. **Credentials**. For each user that `create_login_profile` set to `true`, this code will automatically generate a 
   password that can be used to login to the web console. The password will be encrypted with the user's PGP key and
   visible as a Terraform output. So after you run `apply`, you can copy/paste these encrypted credentials and email
   them to the user.

To deploy this new code and create the new IAM users, you will need to:

1. **Authenticate**. [Authenticate to AWS via the CLI](#authenticate-to-aws-via-the-cli).

1. **Apply your changes**. Run `terragrunt apply`.

1. **Send credentials**. Copy / paste the login URL, usernames, and (encrypted) credentials and email them to your team 
   members. Make sure to tell each team member to follow the [Configure your IAM user](#configure-your-iam-user) 
   instructions to (a) login, (b) reset their passsword, and (c) enable MFA. **Enabling MFA is required in the 
   Reference Architecture**. Without MFA, they will not be able to access anything!  




## Authenticate to the AWS Web Console

1. [Authenticate to the AWS Web Console in the security account](#authenticate-to-the-aws-web-console-in-the-security-account)
1. [Authenticate to the AWS Web Console in all other accounts](#authenticate-to-the-aws-web-console-in-all-other-accounts)


### Authenticate to the AWS Web Console in the security account 

To authenticate to the security account, you will need to:

1. **Login URL**. This should be of the format `https://<ACCOUNT ID>.signin.aws.amazon.com/console`.
1. **IAM User Credentials**. This will consist of a username and password. See [setting up initial 
   access](#setting-up-initial-access) for how to create IAM users.
1. **An MFA Token**. This is something you must set up during your first login. See [configuring your IAM 
   user](#configure-your-iam-user).   

Once you have these details, open your web browser to the Login URL, enter your username, password, and MFA token, and
you should be in. 


### Authenticate to the AWS Web Console in all other accounts

To authenticate to any other account (e.g., dev, stage, prod), you need to:

1. [Authenticate to the security account](#authenticate-to-the-aws-web-console-in-the-security-account). Since all IAM 
   users are defined in this account, you must always authenticate to it first.

1. [Switching to an IAM Role in the other AWS account](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-console.html).
   To access other accounts, you "switch" to (AKA, "assume") an IAM role defined in that account: e.g., to get 
   read-only access to an account, you could assume the `allow-read-only-access-from-other-accounts` IAM role. See the 
   [cross-account-iam-roles module](https://github.com/gruntwork-io/module-security/tree/master/modules/cross-account-iam-roles#iam-roles-intended-for-human-users)
   for the default set of IAM roles that exist in each account. Note that to be able to access an IAM role `xxx` in
   some account `yyy`, your IAM user must be in an IAM group that has permissions to assume that IAM role. For example,
   to assume the `allow-read-only-access-from-other-accounts` IAM role in the prod account, you must be in the 
   `_account.prod-read-only` IAM group. See [Configure other IAM users](#configure-other-iam-users) for how you add
   users to IAM groups.




## Authenticate to AWS via the CLI

A few important notes on authenticating via the CLI:

1. **You will need access keys**. See [configuring your IAM user](#configure-your-iam-user) for instructions.

1. **You will need an MFA token**. MFA is **required** for the Reference Architecture, including on the CLI. See
   [configuring your IAM user](#configure-your-iam-user) for instructions on setting up an MFA token.

1. **You will need to assume an IAM role in most accounts**. To authenticate to the security account, you only need
   your access keys and an MFA token. To authenticate to all other accounts (e.g., dev, stage, prod), you will need
   access keys, an MFA token, and the ARN of an IAM role in that account to assume: e.g., to get read-only access to an 
   account, you could assume the `allow-read-only-access-from-other-accounts` IAM role. See the 
   [cross-account-iam-roles module](https://github.com/gruntwork-io/module-security/tree/master/modules/cross-account-iam-roles#iam-roles-intended-for-human-users)
   for the default set of IAM roles that exist in each account. Note that to be able to access an IAM role `xxx` in
   some account `yyy`, your IAM user must be in an IAM group that has permissions to assume that IAM role. For example,
   to assume the `allow-read-only-access-from-other-accounts` IAM role in the prod account, you must be in the 
   `_account.prod-read-only` IAM group. See [Configure other IAM users](#configure-other-iam-users) for how you add
   users to IAM groups.

So how do you actually authenticate to AWS on the CLI? It turns out that there are many ways to do it, each with various
trade-offs, so check out [A Comprehensive Guide to Authenticating to AWS on 
the Command Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)
for all the options. **Our current recommendation is to use [aws-vault](https://github.com/99designs/aws-vault) for all
CLI authentication.**

**TODO**: add example `aws-vault` config / instructions.




## Authenticate to the VPN server

For security reasons, just about all of the EC2 Instances run in private subnets, which means they do not have a 
public IP address, and cannot be reached directly from the public Internet. This reduces the "surface area" that 
attackers can reach. Of course, we still need access into the VPCs, so we expose a single entrypoint into the network:
an [OpenVPN server](https://openvpn.net/).

The idea is that you use an OpenVPN client to connect to the OpenVPN server, which gets you "in" to the network, and
you can then connect to other resources in the account as if you were making requests from the OpenVPN server itself.

Here are the steps you'll need to take:

1. [Install an OpenVPN client](#install-an-openvpn-client)
1. [Join the OpenVPN IAM group](#join-the-openvpn-iam-group)
1. [Use openvpn-admin to generate a configuration file](#use-openvpn-admin-to-generate-a-configuration-file)
1. [Connect to the OpenVPN server](#connect-to-the-openvpn-server)


### Install an OpenVPN client

There are free and paid OpenVPN clients available for most major operating systems:

* **OS X**: [Viscosity](https://www.sparklabs.com/viscosity/) or [Tunnelblick](https://tunnelblick.net/).
* **Windows**: [official client](https://openvpn.net/index.php/open-source/downloads.html).
* **Linux**: `apt-get install openvpn` or `yum install openvpn`.


### Join the OpenVPN IAM group

To get access to an OpenVPN server, your IAM user needs access to SQS queues used by that OpenVPN server. Since our
IAM users are defined in one AWS account (security) and the OpenVPN servers are defined in separate AWS accounts 
(stage, prod, etc), that means you need to "switch" to the accounts with the OpenVPN servers by assuming an IAM role 
that has access to the SQS queues in those accounts.

To be able to assume an IAM role, your IAM user needs to be part of an IAM group with the proper permissions, such as 
`_account.xxx-full-access` or `_account.xxx-openvpn-users`, where `xxx` is the name of the account you want to access
(`stage`, `prod`, etc). See [Configure other IAM users](#configure-other-iam-users) for instructions on adding users to
IAM groups.    


### Use openvpn-admin to generate a configuration file

To connect to an OpenVPN server, you need an OpenVPN configuration file, which includes a certificate that you can use
to authenticate. To generate this configuration file, do the following:

1. Install the latest [openvpn-admin binary](https://github.com/gruntwork-io/package-openvpn/releases) for your OS.

1. [Authenticate to AWS via the CLI](#authenticate-to-aws-via-the-cli). You will need to assume an IAM role in the AWS 
   account with the OpenVPN server you're trying to connect to. This IAM role must have access to the SQS queues used 
   by OpenVPN server. Typically, the `allow-full-access-from-other-accounts` or 
   `openvpn-server-allow-certificate-requests-for-external-accounts` IAM role is what you want. 

1. Run `openvpn-admin request --aws-region <AWS REGION> --username <YOUR IAM USERNAME>`.
   
1. This will create your OpenVPN configuration file in the current folder.

1. Load this configuration file into your OpenVPN client.


### Connect to the OpenVPN server

To connect to the OpenVPN server, simply click the "Connect" button next to your configuration file in the OpenVPN 
client! After a few seconds, you should be connected. You will now be able to access all the resources within the AWS
network (e.g., SSH to EC2 instances in private subnets) as if you were "in" the VPC itself.




## Authenticate to EC2 Instances via SSH

You can SSH to any of your EC2 Instances as follows:

* [(Recommended) ssh-grunt](#recommended-ssh-grunt)
* [(For emergency / backup use only) EC2 Key Pairs](#for-emergency--backup-use-only-ec2-key-pairs)


### (Recommended) ssh-grunt

Every EC2 instance has [ssh-grunt](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt) 
installed, which allows you to manage SSH access using IAM groups. Here's how it works:

1. [Add users to SSH IAM Groups](#add-users-to-ssh-iam-groups)
1. [Upload your public SSH key](#upload-your-public-ssh-key)
1. [Figure out your SSH username](#figure-out-your-ssh-username)
1. [Connect to VPN](#connect-to-vpn)
1. [SSH to an EC2 instance](#ssh-to-an-ec2-instance)

#### Add users to SSH IAM Groups

When running `ssh-grunt`, each EC2 instance specifies from which IAM groups it will allow SSH access, and SSH access
with sudo permissions. By default, these IAM group names are `ssh-grunt-users` and `ssh-grunt-sudo-users`, respectively.
To be able to SSH to an EC2 instance, your IAM user must be added to one of these IAM groups (see [Configure other 
IAM users](#configure-other-iam-users) for instructions).

#### Upload your public SSH key

1. [Authenticate to the AWS Web Console in the security account](#authenticate-to-the-aws-web-console-in-the-security-account).

1. Go to your IAM User profile page, select the "Security credentials" tab, and click "Upload SSH public key".

1. Upload your _public_ SSH key (e.g. `~/.ssh/id_rsa.pub`). Do NOT upload your private key. 

#### Figure out your SSH username

Your username for SSH is typically the same as your IAM user name. However, if your IAM user name has special 
characters that are not allowed by operating systems (e.g., most puncuation is not allowed), your SSH username may be a 
bit different, as specified in the [ssh-grunt 
documentation](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt#syncing-users-from-iam). 
For example:

* If your IAM User name is `josh`, your SSH username will also be `josh`.
* If your IAM User name is `josh@gruntwork.io`, your SSH username will be `josh`.
* If your IAM User name is `_gruntwork.josh.padnick`, your SSH username will be `gruntwork_josh_padnick`.

#### Connect to VPN

Since just about all the EC2 instances are deployed into public subnets, you won't be able to access them over the
public Internet. Therefore, you must first [connect to the VPN server](#connect-to-the-openvpn-server). 

#### SSH to an EC2 instance

Let's assume that:

- Your IAM User name is `josh`.
- You've uploaded your public SSH key to your IAM User profile.
- Your private key is located at `/Users/josh/.ssh/id_rsa` on your local machine.
- Your EC2 Instance's IP address is `1.2.3.4`. 

Then you can SSH to the EC2 Instance as follows:

```bash
# Do this once to load your SSH Key into the SSH Agent
ssh-add /Users/josh/.ssh/id_rsa

# Every time you want to login to an EC2 Instance, use this command
ssh josh@1.2.3.4
```


### (For emergency / backup use only) EC2 Key Pairs

When you launch an EC2 Instance in AWS, you can specify an [EC2 Key 
Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) that can be used to SSH into the EC2 
Instance. This suffers from an important problem: usually more than one person needs access to the EC2 Instance, which 
means you have to share this key with others. Sharing secrets of this sort is a security risk. Moreover, if someone 
leaves the company, to ensure they no longer have access, you'd have to change the Key Pair, which requires redeploying 
all of your servers.

As part of the Reference Architecture deployment, Gruntwork will create EC2 Key Pairs and put the private keys into
AWS Secrets Manager. These keys are there only for emergency / backup use: e.g., if there's a bug in `ssh-grunt` that
prevents you from accessing your EC2 instances. We recommend only giving a handful of trusted admins access to these
Key Pairs.




## Authenticate to Kubernetes and Helm

Up to this point we focused on accounts and authentication in AWS. However, with EKS, Kubernetes adds another layer of
accounts and authentication that are tied to, but not exactly the same as, AWS IAM.

In this section, you'll learn about Kubernetes RBAC roles and Helm authentication:

* [RBAC basics](#rbac-basics)
* [Relation to IAM roles](#relation-to-iam-roles)
* [Namespaces and RBAC](#namespaces-and-rbac)
* [Accessing to the cluster](#accessing-the-cluster)
    * [Terragrunt / Terraform](#terragrunt--terraform)
    * [Kubectl](#kubectl)
    * [Helm](#helm)


### RBAC basics

[Role Based Access Control (RBAC)](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) is a method to regulate
access to resources based on the role that individual users assume in an organization. Kubernetes allows you to define
roles in the system that individual users inherit, and explicitly grant permissions to resources within the system to
those roles. The Control Plane will then honor those permissions when accessing the resources on Kubernetes through
clients such as `kubectl`. When combined with namespaces, you can implement sophisticated control schemes that limit the
access of resources across the roles in your organization.

The RBAC system is managed using `ClusterRole` and `ClusterRoleBinding` resources (or `Role` and `RoleBinding` resources
if restricting to a single namespace). The `ClusterRole` (or `Role`) object defines a role in the Kubernetes system that
has explicit permissions on what it can and cannot do. These roles are then bound to users and groups using the
`ClusterRoleBinding` (or `RoleBinding`) resource. An important thing to note here is that you do not explicitly create
users and groups using RBAC, and instead rely on the authentication system to implicitly create these entities.

You can refer to [Gruntwork's RBAC example
scenarios](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-role-mapping#examples) for use
cases.


### Relation to IAM Roles

EKS manages authentication to Kubernetes based on AWS IAM roles and users. This is done by embedding AWS IAM credentials
(the access key and secret key) into the authentication token used to authenticate to the Kubernetes API. The API server
then forwards this to AWS to validate it, and then reconciles the role / user into an RBAC user and group that is then
used to reconcile authorization rules for the API.

By default all IAM roles and users (except for the role / user that deployed the cluster) has no RBAC user or groups
associated with it. This automatically translates the role / user into an anonymous user on the cluster, who by default
has no permissions. In order to allow access to the cluster, you need to explicitly bind the IAM role / user to an RBAC
entity, and then bind `Roles` or `ClusterRoles` that explicitly grants permissions to perform actions on the cluster.
This mapping is handled by the [eks-k8s-role-mapping
module](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-role-mapping).

You can read more about the relationship between IAM roles and RBAC roles in EKS in [the official
documentation](https://docs.aws.amazon.com/eks/latest/userguide/managing-auth.html).


### Namespaces and RBAC

[Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) are Kubernetes resources
that creates virtual partition boundaries in your cluster. The resources in each `Namespace` are isolated from other
`Namespaces`, and can only interact with them through `Service` endpoints, unless explicit permissions are granted. This
allows you to divide the cluster between multiple users in a way that prevents them from seeing each others' resources,
allowing you to share clusters while protecting sensitive information.

RBAC is critical in achieving isolation of `Namespaces`. The RBAC permissions can be restricted by `Namespace`. This
allows you to bind permissions to entities such that they can only perform certain actions on resources within a
particular `Namespace`.

Refer to the [eks-k8s-role-mapping module
docs](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-role-mapping#restricting-by-namespace)
for an example on using RBAC to restrict actions to a particular `Namespace`.

Every EKS cluster comes with two default `Namespaces`:

- `kube-system`: This `Namespace` holds admin and cluster level resources. Only cluster administrators ("superusers")
  should have access to this `Namespace`.
- `default`: This is the default `Namespace` that is used for API calls that don't specify a particular `Namespace`.
  This should primarily be used for development and experimentation purposes.

Additionally, in the Reference Architecture, we create another `Namespace`: `applications`. This `Namespace` is used to
house the deployed sample applications and its associated resources.

Most Kubernetes tools will let you set the `Namespace` as CLI args. For example, `kubectl` supports a `-n` parameter for
specifying which `Namespace` you intend to run the command against. `kubectl` additionally supports overriding the
default `Namespace` for your commands by binding a `Namespace` to your authentication context.


### Accessing the cluster

As mentioned in [Relation to IAM Roles](#relation-to-iam-roles), EKS proxies Kubernetes authentication through AWS IAM
credentials. This means that you need to be authenticated to AWS first in order to authenticate to Kubernetes. Refer to
[the previous section on authenticating to AWS via the CLI](#authenticate-to-aws-via-the-cli) for information on how 
to authenticate to AWS.

There are three main ways to interact with Kubernetes in the Reference Architecture:

* [Using Terragrunt / Terraform](#terragrunt--terraform)
* [Using kubectl](#kubectl)
* [Using Helm](#helm)

#### Terragrunt / Terraform

When deploying Kubernetes resources using Terragrunt / Terraform, all the authentication is handled inside of Terraform
using a combination of EKS data sources and provider logic. What this means is that you don't have to worry about
explicitly authenticating to Kubernetes when going through Terraform, as long as you are authenticating to an IAM role
that has a valid mapping to an RBAC entity in the cluster.

The one exception to this is the modules that depend on `helm`, which requires additional configuration. See the
[section on helm](#helm) for more info.

#### Kubectl

Most manual operations in Kubernetes are handled through [the kubectl command line
utility](https://kubernetes.io/docs/reference/kubectl/overview/). `kubectl` requires an explicit authentication
configuration to access the cluster.

You can use `kubergrunt` to configure your local `kubectl` client to authenticate against a deployed EKS cluster. After
authenticating to AWS, run:

```bash
kubergrunt eks configure --eks-cluster-arn $EKS_CLUSTER_ARN
```

This will add a new entry to your `kubectl` config file (defaults to `$HOME/.kube/config`) with the logic for
authenticating to EKS, registering it under the context name `$EKS_CLUSTER_ARN`. You can modify the name of the context
using the `--kubectl-context-name` CLI arg.

You can verify the setup by running:

```bash
kubectl cluster-info
```

This will report information about the Kubernetes endpoints for the cluster only if you are authorized to access to the
cluster. Note that you will need to be authenticated to AWS for `kubectl` to successfully authenticate to the cluster.

If you have multiple clusters, you can switch the `kubectl` context using the `use` command. For example, to switch the
current context to the `dev` EKS cluster from the `prod` cluster and back:

```bash
kubectl use arn:aws:eks:$AWS_REGION:$DEV_ACCOUNT_ID:cluster/eks-dev
kubectl cluster-info  # Should target the dev EKS cluster
kubectl use arn:aws:eks:$AWS_REGION:$PROD_ACCOUNT_ID:cluster/eks-prod
kubectl cluster-info  # Should target the prod EKS cluster
```

#### Helm

Helm relies on TLS based authentication and authorization to access Tiller (the Helm Server). This is separate from the
RBAC based authorization native to Kubernetes. Intuitively, RBAC is used to manage whether or not someone can lookup the
`Pod` endpoint address, while the TLS authentication and authorization scheme manages whether or not you can establish a
connection to the Tiller server. All deployments of Tiller in the Reference Architecture uses `kubergrunt` to manage the
TLS certificates.

We highly recommend reading [Gruntwork's guide to
helm](https://github.com/gruntwork-io/kubergrunt/blob/master/HELM_GUIDE.md) to understand the security model surrounding
Helm and Tiller.

`kubergrunt` manages the TLS certificates using Kubernetes `Secrets`, guarded by RBAC roles. A cluster administrator can
grant access to any RBAC entity to any Tiller deployment using the `kubergrunt helm grant` command. For example, to
grant access to a Tiller server deployed in the namespace `applications-tiller` to the RBAC user
`jane_doe`:

```bash
kubergrunt helm grant \
    --tls-common-name jane_doe \
    --tls-org <YOUR COMPANY NAME> \
    --tiller-namespace applications \
    --rbac-user jane_doe
```

**Note on RBAC users**: The RBAC user username (`--rbac-user`) corresponds to the IAM Role or User name of the
authenticating AWS credentials.

This generates new TLS certificate key pairs that grant access to the Tiller deployed in the `applications-tiller`
Namespace. In addition, this creates and binds RBAC roles that allow users of the RBAC group `developers` to be able to
read the necessary `Secrets` to download the generated TLS certificate key pairs.

Now anyone who maps to the `developers` RBAC group can use the `kubergrunt helm configure` command to setup their
helm client to access the deployed Tiller:

```bash
kubergrunt helm configure \
    --tiller-namespace applications-tiller \
    --resource-namespace applications \
    --rbac-user jane_doe
```

This will:

- Download the client TLS certificate key pair generated with the `grant` command.
- Install the TLS certificate key pair in the helm home directory (defaults to `$HOME/.helm`).
- Install an environment file that sets up environment variables to target the specific helm server (defaults to
  `$HELM_HOME/env`). This environment file needs to be loaded before issuing any commands, at it sets the necessary
  environment variables to signal to the helm client which helm server to use. The environment variables it sets are:
  - `HELM_HOME`: The helm client home directory where the TLS certs are located.
  - `TILLER_NAMESPACE`: The namespace where the helm server is installed.
  - `HELM_TLS_VERIFY`: This will be set to true to enable TLS verification.
  - `HELM_TLS_ENABLE`: This will be set to true to enable TLS authentication.

Once this is setup, Terraform modules that need to access `helm` will be able to use the downloaded credentials to
authenticate to Tiller. Additionally, once you source the environment file, you will be able to use the `helm` client to
directly work with Tiller.

If you have the `helm` client installed, you can verify your configuration setup using the `helm version` command:

```bash
helm version
```

If your `helm` client is configured correctly, the `version` command will output information about the deployed Tiller
instance that it connected to.




## Next steps

Now that you know how to authenticate, it's time to learn how to [deploy your apps into the Reference 
Architecture](03-deploy-apps.md).
