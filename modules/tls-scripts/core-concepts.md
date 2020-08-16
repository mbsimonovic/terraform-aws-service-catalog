# TLS Scripts Core Concepts

## Background

### How does TLS/SSL work?

The industry-standard way to add encryption for data in motion is to use TLS (the successor to SSL). There are many examples
online explaining how TLS works, but here are the basics:

- Some entity decides to be a _Certificate Authority_ (_CA_) meaning it will issue TLS certificates to websites or
    other services.
- An entity becomes a Certificate Authority by creating a public/private key pair and publishing the public portion (typically
    known as the _CA Cert_). The private key is kept under the tightest possible security since anyone who possesses it could issue
    TLS certificates as if they were this Certificate Authority!
- In fact, the consequences of a CA's private key being compromised are so disastrous that CAs typically create an _intermediate_
    CA keypair with their _root_ CA key, and only issue TLS certificates with the intermediate key.
- Your client (e.g. a web browser) can decide to trust this newly created Certificate Authority by including its CA Cert
    (the CA's public key) when making an outbound request to a service that uses the TLS certificate.
- When CAs issue a TLS certificate to a service, they again create a public/private keypair, but this time the
    public key is _signed_ by the CA. That public key is what you see when you click on the lock icon in a web browser
    and what a service _advertises_ to any clients, such as web browsers, to declare who it is. When we say that the CA
    signed a public key, we mean that cryptographically any possessor of the CA Cert can validate that this same CA
    issued this particular public key.
- The public key is more generally known as the TLS cert.
- The private key created by the CA must be kept secret by the service since the possessor of the private key can prove
    they are whomever the TLS cert (public key) claims to be as part of the TLS protocol.
- How does that proof work? Well, your web browser will attempt to validate the TLS cert in two ways:
    - First, the web browser will ensure this public key (TLS cert) is in fact signed by a CA it trusts.
    - Second, using the TLS protocol, the browser will encrypt a message with the public key (TLS cert) that only the
        possessor of the corresponding private key can decrypt. In this manner, your browser will be able to come up with a
        symmetric encryption key it can use to encrypt all traffic for just that one web session.
- Now your client/browser has:
    - declared which CA it will trust,
    - verified that the service it's connecting to possesses a certificate issued by a CA it trusts,
    - and used that service's public key (TLS cert) to establish a secure session.

### What are commercial or public Certificate Authorities?

For public services like banks, healthcare, and the like, it makes sense to use a _Commercial CA_ like Verisign, Thawte,
or Digicert, or better yet a widely trusted but free service like [Let's Encrypt](https://letsencrypt.org/).
(For additional information on Let's Encrypt, see [Alternative Solutions Considered](#alternative-solutions-considered)
in this document.) That's because every web browser comes pre-configured with a set of CAs that it trusts. This means
the client connecting to the bank doesn't have to know anything about CAs at all. Instead, their web browser is
configured to trust the CA that happened to issue the bank's certificate.

Connecting securely to private services is similar to connecting to your bank's website over TLS, with one primary
difference: **We want total control over the CA.**

Imagine if we used a commercial CA to issue our private TLS certificate and that commercial or public CA -- which we
don't control -- were compromised. Now the attackers of that commercial or public CA could impersonate our private server.
And indeed,
[it](https://www.theguardian.com/technology/2011/sep/05/diginotar-certificate-hack-cyberwar)
[has](https://www.schneier.com/blog/archives/2012/02/verisign_hacked.html)
[happened](http://www.infoworld.com/article/2623707/hacking/the-real-security-issue-behind-the-comodo-hack.html)
multiple times.

### How does Gruntwork generate a TLS cert for private services?

One option is to be very selective about choosing a commercial CA, but to what benefit? What we want instead is assurance
that our private service really was launched by people we trust. Those same people -- let's call them our _operators_ --
can become their *own* CA and generate their *own* TLS certificate for the private service.

Sure, no one else in the world will trust this CA, but we don't care because we only need our organization to trust this CA.

So here's our strategy for issuing a TLS cert for a private service:

1. **Create our own CA.**
    - If a client wishes to trust our CA, they need only reference this CA public key.
    - We'll deal with the private key in a moment.

1. **Using our CA, issue a TLS certificate for our private service.**
    - Create a public/private key pair for the private service, and have the CA sign the public key.
    - This means anyone who trusts the CA will trust that the possessor the private key that corresponds to this public key
    is who they claim to be.
    - We will be extremely careful with the TLS private key since anyone who obtains it can impersonate our private service!
    This is why we recommend immediately encrypting the private key with [AWS KMS](https://aws.amazon.com/kms/) by
    using [gruntkms](https://github.com/gruntwork-io/gruntkms).

1. **Freely advertise our CA's public key to all internal services.**
    - Any service that wishes to connect securely to our private service will need our CA's public key. That way the
    service can declare that it trusts this CA, and thereby the TLS cert that the CA issued to the private service.

1. **Finally, consider throwing away the CA private key.**
    - By erasing a CA private key it's impossible for the CA to be compromised, because there's no private key to steal!
    - Future certs can be generated with a new CA.
    - Contrast this to protecting your CA private key. There are trade-offs either way so choose the option that makes
    the most sense for your organization.

[back to readme](README.adoc#about-tls)

## Alternative Solutions Considered

### Terraform's TLS Provider

A compelling alternative is to use Teraform's built-in [TLS Provider](https://www.terraform.io/docs/providers/tls/index.html).
The primary concern with this approach is that the TLS private key generated by the `tls_private_key` Terraform resource
is stored in plaintext in the Terraform state and is therefore not recommended for production use.

### Let's Encrypt

[Let's Encrypt](https://letsencrypt.org) behaves in every way like a traditional commercial Certificate Authority (CA),
except that it's free. Because Let's Encrypt has good documentation around how to generate and automatically renew a
TLS Certificate, it seemed like a good solution to solve our problem.

Unfortunately, Let's Encrypt is optimized for public services, not private ones. As a result, when issuing a new TLS
certificate, operators must prove ownership of their domain name by either provisioning a DNS record under `example.com`
or provisioning an HTTP resource under a well-known URI on `https://example.com`. This means it's not possible to
generate a TLS cert for a service with a private DNS address since Let's Encrypt would have no way of either resolving
the domain name (because it's private) or reaching the service to validate an HTTP document (because, again, it's private).

While Let's Encrypt is not the ideal solution for the intent of this module, it's well-suited to automatically generating
TLS certificates for any public services.

[back to readme](README.adoc#about-tls)

## How does create-tls-cert work?

You can use [create-tls-cert.sh](create-tls-cert.sh) to create self-signed TLS certificates. These are appropriate for private / internal services (e.g., for your microservices talking to each other). If you need TLS certificates for public use (e.g., for services directly accessed by your users) you'll need to use a well-known commercial Certificate Authority (CA) such as [AWS Certificate Manager (ACM)](https://aws.amazon.com/certificate-manager/) or [LetsEncrypt](https://letsencrypt.org/) instead.

This script does the following:

1. Create a private CA, including a private key and public key.
1. Create a TLS certificate, including a private key and public key, that is signed by that CA.
1. Delete the private key of the CA so no one can ever use it again. However, the public key of the CA is kept around so anyone who needs to call your service can use that CA public key to verify your TLS certificate.
1. Optionally encrypt the private key of the TLS cert with KMS.
1. Optionally upload the TLS certificate to IAM so you can use it with an internal ELB or ALB.

Optionally with the `--upload-to-iam` flag, [create-tls-cert.sh](create-tls-cert.sh) can also upload the cert to IAM, so it can be used with an ELB or ALB.
These certs are meant for private/internal use only, such as to set up end-to-end encryption within an AWS account.
The only IP address in the cert will be 127.0.0.1 and localhost, so you can test your servers locally.
You can also use the servers with the ELB or ALB, as the AWS load balancers don't verify the CA.
Also see [Loading TLS secrets from AWS Secrets Manager](https://github.com/gruntwork-io/aws-sample-app/blob/master/core-concepts.md#loading-tls-secrets-from-aws-secrets-manager)

[back to readme](README.adoc#about-the-scripts-specifically)

## How does download-rds-ca-certs work?

This script downloads the Certificate Authority certs for RDS so that applications can validate the certs
when connecting to RDS over TLS.

[back to readme](README.adoc#about-the-scripts-specifically)

## How does generate-trust-stores work?

This script automatically generates a Key Store and Trust Store, which are typically used with Java apps to
securely store TLS certificates. If they don't already exist, the Key Store, Trust Store, and public
cert / CA will be generated to the specified paths, and the Key Store password will be stored in AWS
Secrets Manager. The script writes the KMS-encrypted password for the Key Store to `stdout`.

[back to readme](README.adoc#about-the-scripts-specifically)

## How do I run these scripts using Docker?

We've provided a [Dockerfile](Dockerfile) in this module for you to use for both using and testing the TLS scripts.

All the scripts require some environment variables to be set.
1. Export your GitHub OAuth token in `GITHUB_OAUTH_TOKEN`.
1. Export your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
1. If you're using temporary credentials, which is the case if you're assuming an IAM role, using SAML, or using an MFA token,
also export your `AWS_SESSION_TOKEN`.
1. Start Docker.

Now you're ready to run the scripts via Docker.

<!--- TODO Give advice -->
Link to blog post on how to authenticate to AWS.
Do not use the `~/.aws/credentials` file.
Use aws-vault, aws-auth, passwordstore, or something to export environment variables.

[back to readme](README.adoc#running)

## How do I create TLS certs?

To create a TLS cert for your app, the easiest way is to use our provided [docker-compose.yml](docker-compose.yml)
and [Dockerfile](Dockerfile).

1. First make sure you followed [#how-do-i-run-these-scripts-using-docker](these instructions), so that environment
variables are set, and Docker is running.
1. Run the following command (which calls [create-tls-cert.sh](create-tls-cert.sh)):
    ```sh
    docker-compose run tls \
    --ca-path ca.crt.pem \
    --cert-path my-app.crt.pem \
    --key-path my-app.key.pem \
    --company-name Acme \
    --kms-key-id alias/test-key \ # change this to be correct
    --aws-region us-east-1 # change this to be correct
    ```
You'll notice that you need to pass in the correct KMS key id in `--kms-key-id`, and the region where it's located in `--aws-region`.
_We highly recommend including these two options, so that you don't have an unencrypted private key on your system._
By providing both `--kms-key-id` and `--aws-region`, the script will automatically encrypt the private key, save it as
`my-app.key.pem.kms.encrypted`, and delete the unencrypted key, `my-app.key.pem`.
1. After running that command, the generated cert files will be located on your local machine here: `tmp/tls/`. That is, in the same
directory as this module, within a new `tmp` folder.

If you used the above example, you should see:
- `ca.crt.pem`: This is the CA public key, or CA certificate, in PEM format.
- `my-app.crt.pem`: This is the app's public key, or TLS certificate, signed by the CA cert, in PEM format.
- `my-app.key.pem.kms.encrypted`: This is the app's private key in PEM format, encrypted with the KMS key you provided.
- If you see `my-app.key.pem`, the script was not able to encrypt your private key using the KMS key you provided.

Optionally, you can upload the certificate to IAM. Simply add two more flags to the previous command.
- `--upload-to-iam`
- `--cert-name-in-iam` followed by a name you want to use

E.g.:
```sh
docker-compose run tls \
--ca-path ca.crt.pem \
--cert-path my-app.crt.pem \
--key-path my-app.key.pem \
--company-name Acme \
--kms-key-id alias/test-key \ # change this to be correct
--aws-region us-east-1 \ # change this to be correct
--upload-to-iam \
--cert-name-in-iam tls-scripts-test
```

The certificate is uploaded to IAM as a Server Certificate, which cannot be managed using the AWS Console UI.
You must use the AWS API to upload, update, and delete these certs! If you need to list, rename, or delete them,
consult the [https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_server-certs.html](AWS API guide for Server Certificate management).

[back to readme](README.adoc#running)

## How do I download CA public keys for validating RDS TLS connections?

1. First make sure you followed [#how-do-i-run-these-scripts-using-docker](these instructions), so that environment
variables are set, and Docker is running.
1. Run the following command (which calls [download-rds-ca-certs.sh](download-rds-ca-certs.sh)):
    ```sh
    docker-compose run rds tmp/rds-cert
    ```
1. Check `tmp/` in the current directory for a file named `rds-cert`. This is the downloaded file.

[back to readme](README.adoc#running)

## How do I generate key stores and trust stores to manage TLS certificates for JVM apps?

1. First make sure you followed [#how-do-i-run-these-scripts-using-docker](these instructions), so that environment
variables are set, and Docker is running.
1. Run the following command (which calls [generate-trust-stores.sh](generate-trust-stores.sh)):
    ```sh
    generate-trust-stores.sh \
    --keystore-name kafka \
    --store-path /tmp/ssl \
    --vpc-name default \
    --company-name Acme \
    --company-org-unit IT \
    --company-city Phoenix \
    --company-state AZ \
    --company-country US \
    --kms-key-id alias/test-key \
    --aws-region us-east-1
    ```
1. Check `tmp/ssl/` in the current directory for all your created files:
- `kafka.server.ca.default.pem`
- `kafka.server.cert.default.pem`
- `keystore/kafka.server.keystore.default.jks`
- `truststore/kafka.server.truststore.default.jks`

[back to readme](README.adoc#running)

## How do I test these scripts using Docker?

### Setup
1. First make sure you followed [#how-do-i-run-these-scripts-using-docker](these instructions), so that environment
variables are set, and Docker is running.
1. Run `export TLS_SCRIPTS_KMS_KEY_ID=[your-key-name]`, setting it to the ID of the CMK to use for encryption.
This value can be a globally unique identifier (e.g. 12345678-1234-1234-1234-123456789012), a fully specified ARN
(e.g. arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012), or an alias name prefixed by
`alias/` (e.g. `alias/MyAliasName`).
1. Run `export TLS_SCRIPTS_AWS_REGION=[your-key-region]`, setting it to the AWS region where the KMS key is located
(e.g. `us-east-1`).

### Test
1. Okay, now you're ready to run the test suite (all three tests) in the [test file](../../test/tls_scripts_test.go).
    ```sh
    # Assuming you're in this directory:
    cd ../../test
    go test -v -timeout 5m -run TestTlsScripts
    ```
1. The tests do their own cleanup, so you will not see files created in your system, but the tests should pass.

[back to readme](README.adoc#testing)

## How do I use these certs with my apps?

(e.g., passing the public and private key to a Node app)

[back to readme](README.adoc#operate)

## How do I talk to other apps that are listening with certs?

(i.e., by using the CA public key to validate the connection)

[back to readme](README.adoc#operate)
