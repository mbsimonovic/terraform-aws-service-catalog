# TLS Scripts Core Concepts

## Background

### How does TLS/SSL work?

The industry-standard way to add encryption for data in motion is to use TLS (the successor to SSL). There are many examples
online explaining how TLS works, but here are the basics:

- Some entity decides to be a "Certificate Authority" ("CA") meaning it will issue TLS certificates to websites or other services
- An entity becomes a Certificate Authority by creating a public/private key pair and publishing the public portion (typically
    known as the "CA Cert"). The private key is kept under the tightest possible security since anyone who possesses it could issue
TLS certificates as if they were this Certificate Authority!
- In fact, the consequences of a CA's private key being compromised are so disastrous that CA's typically create an "intermediate"
CA keypair with their "root" CA key, and only issue TLS certificates with the intermediate key.
- Your client (e.g. a web browser) can decide to trust this newly created Certificate Authority by including its CA Cert
(the CA's public key) when making an outbound request to a service that uses the TLS certificate.
- When CAs issue a TLS certificate ("TLS cert") to a service, they again create a public/private keypair, but this time
the public key is "signed" by the CA. That public key is what you view when you click on the lock icon in a web browser
and what a service "advertises" to any clients such as web browsers to declare who it is. When we say that the CA
signed a public key, we mean that, cryptographically, any possessor of the CA Cert can validate that this same CA issued
this particular public key.
- The public key is more generally known as the TLS cert.
- The private key created by the CA must be kept secret by the service since the possessor of the private key can "prove"
they are whoever the TLS cert (public key) claims to be as part of the TLS protocol.
- How does that "proof" work? Well, your web browser will attempt to validate the TLS cert in two ways:
- First, it will ensure this public key (TLS cert) is in fact signed by a CA it trusts.
- Second, using the TLS protocol, your browser will encrypt a message with the public key (TLS cert) that only the
possessor of the corresponding private key can decrypt. In this manner, your browser will be able to come up with a
symmetric encryption key it can use to encrypt all traffic for just that one web session.
- Now your client/browser has:
- declared which CA it will trust
- verified that the service it's connecting to possesses a certificate issued by a CA it trusts
- used that service's public key (TLS cert) to establish a secure session

### What are commercial or public Certificate Authorities?

For public services like banks, healthcare, and the like, it makes sense to use a "Commercial CA" like Verisign, Thawte,
    or Digicert, or better yet a widely trusted but free service like [Let's Encrypt](https://letsencrypt.org/).
    (For additional information on Let's Encrypt, see [Alternative Solutions Considered](#alternative-solutions-considered)
     in this document.) That's because every web browser comes pre-configured with a set of CA's that it trusts. This means
    the client connecting to the bank doesn't have to know anything about CA's at all. Instead, their web browser is
    configured to trust the CA that happened to issue the bank's certificate.

Connecting securely to private services is similar to connecting to your bank's website over TLS, with one primary
difference: **We want total control over the CA.**

Imagine if we used a commercial CA to issue our private TLS certificate and that commercial or public CA -- which we
don't control -- were compromised. Now the attackers of that commercial or public CA could impersonate our private server.
And indeed, [it](https://www.theguardian.com/technology/2011/sep/05/diginotar-certificate-hack-cyberwar) [has](https://www.schneier.com/blog/archives/2012/02/verisign_hacked.html) [happened](http://www.infoworld.com/article/2623707/hacking/the-real-security-issue-behind-the-comodo-hack.html)
multiple times.

### How does Gruntwork generate a TLS cert for private services?

One option is to be very selective about choosing a commercial CA, but to what benefit? What we want instead is assurance
that our private service really was launched by people we trust. Those same people -- let's call them our "operators" --
can become their *own* CA and generate their *own* TLS certificate for the private service.

Sure, no one else in the world will trust this CA, but we don't care because we only need our organization to trust this CA.

So here's our strategy for issuing a TLS Cert for a private service:

1. **Create our own CA.**
- If a client wishes to trust our CA, they need only reference this CA public key.
- We'll deal with the private key in a moment.

1. **Using our CA, issue a TLS Certificate for our private service.**
- Create a public/private key pair for the private service, and have the CA sign the public key.
- This means anyone who trusts the CA will trust that the possessor the private key that corresponds to this public key
is who they claim to be.
- We will be extremely careful with the TLS private key since anyone who obtains it can impersonate our private service!
For this reason, we recommend immediately encrypting the private key with [AWS KMS](https://aws.amazon.com/kms/) by
using [gruntkms](https://github.com/gruntwork-io/gruntkms).

1. **Freely advertise our CA's public key to all internal services.**
- Any service that wishes to connect securely to our private service will need our CA's public key so it can declare
that it trusts this CA, and thereby the TLS cert it issued to the private service.

1. **Finally, consider throwing away the CA private key.**
- By erasing a CA private key it's impossible for the CA to be compromised, because there's no private key to steal!
- Future certs can be generated with a new CA.
- Contrast this to protecting your CA private key. There are trade-offs either way so choose the option that makes
the most sense for your organization.

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

## How do I use Docker to run these scripts?

We've provided a [Dockerfile](Dockerfile) in this module for you to use for both running and testing the TLS scripts.
Open a terminal in this directory and run `docker build -t {image name} --build-arg GITHUB_OAUTH_TOKEN={your github-oauth-token} .` to create a docker container with all the dependencies needed to run the scripts and the tests.
Then you can run `docker run --rm -it -v /tmp:/tmp {image name} bash` to run the scripts interactively in the container and check their outputs.

[back to readme](README.adoc#running)

## How do I use Docker to create TLS certs?

For example, to run the [create-tls-cert.sh](create-tls-cert.sh) script interactively in Docker, you'll have to pass in environment variables to the `run` command.

```sh
docker run \
--rm -it \
-v /tmp:/tmp \
-e AWS_ACCESS_KEY_ID={your key id} \
-e AWS_SECRET_ACCESS_KEY={your secret key} \
{image name} bash
```

Then while in the container's shell, you can run the example call, which doesn't upload the cert to IAM:

```sh
create-tls-cert.sh \
--ca-path ca.crt.pem \
--cert-path my-app.crt.pem \
--key-path my-app.key.pem.kms.encrypted \
--company-name Acme
```

The generated cert files are located in `/tmp/vault-blueprint/modules/private-tls-cert/`, both in the docker container
and in your local machine. This is because we used `-v /tmp:/tmp` to bind-mount the `/tmp` volume of the container to your machine.

To upload the cert to IAM, include the `--upload-to-iam` flag along with the correct KMS key id in `--kms-key-id`, and the correct
region for that key in `--aws-region`. The cert is uploaded to IAM as a Server Certificate, which cannot be managed using the AWS
Console UI. You must use the AWS API to upload, update, and delete these certs.

```sh
create-tls-cert.sh \
--ca-path ca.crt.pem \
--cert-path my-app.crt.pem \
--key-path my-app.key.pem.kms.encrypted \
--company-name Acme \
--kms-key-id alias/test-key \
--aws-region us-east-1 \
--upload-to-iam
```

Check `/tmp/vault-blueprint/modules/private-tls-cert/` for output cert files.
If you used the above example, you should see `ca.crt.pem`, `my-app.crt.pem`, and `my-app.key.pem.kms.encrypted`.

[back to readme](README.adoc#running)

## How do I use Docker to download CA public keys for validating RDS TLS connections?

```sh
download-rds-ca-certs.sh PATH
```

Check `/tmp/` for a file named `rds-cert`. This is the downloaded file.

[back to readme](README.adoc#running)

## How do I use Docker to generate key stores and trust stores to manage TLS certificates for JVM apps?

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

Check `/tmp/ssl/` for all your created files:
`kafka.server.ca.default.pem`, `kafka.server.cert.default.pem`, `keystore/kafka.server.keystore.default.jks`,
and `truststore/kafka.server.truststore.default.jks`

[back to readme](README.adoc#running)

## How do I use Docker to test these scripts?

### Setup
1. First make sure Docker is running.
1. Export your github oauth token into `GITHUB_OAUTH_TOKEN`. For example, if you're using [pass](passwordstore.org),
you might run `export GITHUB_OAUTH_TOKEN=$(pass github-oauth-token)`. If you are pasting your token into the
terminal in plain text, use a leading space in ` export GITHUB_OAUTH_TOKEN=...` so that your shell history does
not save that token.
<!-- TODO link to best practices for local secrets -->

1. Make sure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set in your environment.
  - If you're using temporary credentials, `AWS_SESSION_TOKEN` also must be set.
1. Export a KMS key (CMK) in `TLS_SCRIPTS_KMS_KEY_ID` and its region in `TLS_SCRIPTS_AWS_REGION`.

### Test
1. Okay, now you're ready to run the test suite (all three tests) in the [test file](../../test/tls_scripts_test.go).

```sh
# Assuming you're in this directory:
cd ../../test
go test -v -timeout 15m -run TestTlsScripts
```
1. The test suite builds a docker image and runs commands against it. The tests do their own cleanup, so you will not see files created in your system.


[back to readme](README.adoc#testing)

## How do I use these certs with my apps?

(e.g., passing the public and private key to a Node app)

[back to readme](README.adoc#operate)

## How do I talk to other apps that are listening with certs?

(i.e., by using the CA public key to validate the connection)

[back to readme](README.adoc#operate)
