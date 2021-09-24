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
email address for each account; if you don't know what those email addresses were, you can login to the root account
(the parent of the AWS Organization) and go to the [AWS Organizations
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

Please note that you'll want to repeat the process above of resetting the password and enabling MFA for _every_
account in your organization: dev, stage, prod, shared-services, security, and the root account too!


### Configure your IAM user

All IAM users are defined and managed in the security account. As part of deploying a Reference Architecture for you,
Gruntwork created an IAM user with admin permissions in the security account. The password is encrypted via PGP using
[Keybase](https://keybase.io/) and [Base64-encoded](https://en.wikipedia.org/wiki/Base64).

However, to access the Terraform state containing the password, you need to already be authenticated to the account.
Thus to get access to the initial admin IAM user, we will use the root user credentials. To do this, you can **either**:

- Login on the AWS Web Console using the root user credentials for the `security` account and use the web console to
  setup the web console password and AWS Access Keys for the IAM user.
- Use the [gruntwork CLI](https://github.com/gruntwork-io/gruntwork/) to rotate the password using the command:

      gruntwork aws reset-password --iam-user-name <IAM_username>


Once you have access with the IAM user, be sure to do the following to finish configuring the user:

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
   [IAM groups module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-groups#iam-groups).

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
   [cross-account-iam-roles module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/cross-account-iam-roles#iam-roles-intended-for-human-users)
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
   [cross-account-iam-roles module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/cross-account-iam-roles#iam-roles-intended-for-human-users)
   for the default set of IAM roles that exist in each account. Note that to be able to access an IAM role `xxx` in
   some account `yyy`, your IAM user must be in an IAM group that has permissions to assume that IAM role. For example,
   to assume the `allow-read-only-access-from-other-accounts` IAM role in the prod account, you must be in the
   `_account.prod-read-only` IAM group. See [Configure other IAM users](#configure-other-iam-users) for how you add
   users to IAM groups.

So how do you actually authenticate to AWS on the CLI? It turns out that there are many ways to do it, each with various
trade-offs, so check out [A Comprehensive Guide to Authenticating to AWS on
the Command Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)
for all the options. Our current recommendation is to use [aws-vault](https://github.com/99designs/aws-vault) for all CLI authentication.

### Using aws-vault with the Reference Architecture

We recommend [aws-vault](https://github.com/99designs/aws-vault) for its wide platform support, variety of backends, MFA support, and ease of use with the shell.

Do the following steps to configure aws-vault for use with the reference architecture:

* [Install aws-vault](https://github.com/99designs/aws-vault#installing).
* Make sure your IAM user has MFA configured, as mentioned above.
* Add your IAM user credentials:
```
aws-vault add security
```
* Add new profiles for each of the accounts to `~/.aws/config`. We have generated a configuration for you.

```
[default]
region=us-west-2

[profile security]
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork

[profile dev]
source_profile = security
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork
role_arn = arn:aws:iam::345678901234:role/allow-full-access-from-other-accounts

[profile logs]
source_profile = security
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork
role_arn = arn:aws:iam::012345678901:role/allow-full-access-from-other-accounts

[profile prod]
source_profile = security
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork
role_arn = arn:aws:iam::567890123456:role/allow-full-access-from-other-accounts


[profile shared]
source_profile = security
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork
role_arn = arn:aws:iam::234567890123:role/allow-full-access-from-other-accounts

[profile stage]
source_profile = security
mfa_serial = arn:aws:iam::123456789012:mfa/gruntwork
role_arn = arn:aws:iam::456789012345:role/allow-full-access-from-other-accounts

```

Once configured, you can use AWS vault with Terragrunt, Terraform, the AWS CLI, and anything else that uses the AWS SDK to authenticate. To check if your authentication is working, you can run `aws sts caller-identity`:

```
aws-vault exec dev -- aws sts get-caller-identity
```

Note that in some cases, you may need to change this to:

```
aws-vault exec dev --no-session -- aws sts get-caller-identity
```

This avoids using an STS session, which may lead to an error, depending on the command that you're running.

You can also use `aws-vault` to log in to the web console for each account:

```
aws-vault login dev --duration 8h -s
```

This will print a URL that you can paste in to a browser and be immediately logged in to the `dev` account.

Be sure to read [`USAGE.md`](https://github.com/99designs/aws-vault/blob/master/USAGE.md) for details and many helpful hints for using aws-vault.
## Authenticate to the VPN server

For security reasons, just about everything runs in private subnets, which means they do not have a
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

1. Install the latest [openvpn-admin binary](https://github.com/gruntwork-io/terraform-aws-openvpn/releases) for your OS.

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

Every EC2 instance has [ssh-grunt](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt)
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
documentation](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt#syncing-users-from-iam).
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





## Next steps

Now that you know how to authenticate, it's time to learn how to [deploy your apps into the Reference
Architecture](03-deploy-apps.md).
