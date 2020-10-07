# TLS Scripts Core Concepts

## Background

### How does TLS/SSL work?

The industry-standard way to add encryption for data in motion is to use TLS (the successor to SSL). There are many
examples online explaining how TLS works, but here are the basics:

- Some entity decides to be a _Certificate Authority_ (_CA_) meaning it will issue TLS certificates to websites or
    other services.
- An entity becomes a Certificate Authority by creating a public/private key pair and publishing the public portion
    (typically known as the _CA Cert_). The private key is kept under the tightest possible security since anyone who
    possesses it could issue TLS certificates as if they were this Certificate Authority!
- In fact, the consequences of a CA's private key being compromised are so disastrous that CAs typically create an
   _intermediate_ CA keypair with their _root_ CA key, and only issue TLS certificates with the intermediate key.
- Your client (e.g. a web browser) can decide to trust this newly created Certificate Authority by including its CA
  Cert (the CA's public key) when making an outbound request to a service that uses the TLS certificate.
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
        possessor of the corresponding private key can decrypt. In this manner, your browser will be able to come up
        with a symmetric encryption key it can use to encrypt all traffic for just that one web session.
- Now your client/browser has:
    - declared which CA it will trust,
    - verified that the service it's connecting to possesses a certificate issued by a CA it trusts,
    - and used that service's public key (TLS cert) to establish a secure session.


For more information, check out this [illustrated guide to the entire TLS process.](https://tls13.ulfheim.net/)

[back to readme](README.adoc#about-tls)



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

[back to readme](README.adoc#about-tls)

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

You can use [create-tls-cert.sh](create-tls-cert.sh) to create self-signed TLS certificates. These are meant for
private / internal services only, such as to set up end-to-end encryption within an AWS account, or for your
microservices to talk to each other. If you need TLS certificates for public use (e.g., for services directly
accessed by your users) you'll need to use a well-known commercial Certificate Authority (CA) such as
[AWS Certificate Manager (ACM)](https://aws.amazon.com/certificate-manager/)
or [LetsEncrypt](https://letsencrypt.org/) instead.

This script does the following:

1. Create a private CA, including a private key and public key.
1. Create a TLS certificate, including a private key and public key, that is signed by that CA.
1. Delete the private key of the CA so no one can ever use it again. However, the public key of the CA is kept
around so anyone who needs to call your service can use that CA public key to verify your TLS certificate.
1. Optionally upload the private key, public key, and CA to AWS Secrets Manager using the default CMK for encryption,
or the KMS key you provide.
1. Optionally upload the TLS certificate to AWS Certificate Manager so you can use it with an internal ELB or ALB.
The ARN of the certificate will be output to `stdout`.
1. Optionally encrypt the private key of the TLS cert with KMS in local storage.

By default, the only IP address in the cert will be 127.0.0.1, and the only DNS name in the cert will be localhost,
so you can test your servers locally. But you can pass in optional parameters to customize the DNS names and IP
addresses in the cert. You can also use the servers with the ELB or ALB, as the AWS load balancers don't verify the CA.
See [Loading TLS secrets from AWS Secrets Manager](https://github.com/gruntwork-io/aws-sample-app/blob/master/core-concepts.md#loading-tls-secrets-from-aws-secrets-manager).

[back to readme](README.adoc#about-the-scripts-specifically)

## How does download-rds-ca-certs work?

This script downloads the Certificate Authority certs for RDS so that applications can validate the certs
when connecting to RDS over TLS.

[back to readme](README.adoc#about-the-scripts-specifically)

## How does generate-trust-stores work?

This script generates a Key Store and Trust Store, which are typically used with Java apps to securely store TLS
certificates. If they don't already exist, the Key Store, Trust Store, and public cert / CA will be generated to
the specified paths.

Optionally the Key Store password can be stored in AWS Secrets Manager. The script writes the KMS-encrypted password for the Key Store to `stdout`.

[back to readme](README.adoc#about-the-scripts-specifically)

## How do I run these scripts using Docker?

We recommend running the scripts with Docker to avoid cluttering up your development environment. We've provided
a [Dockerfile](Dockerfile) in this module for you to use for both using and testing the TLS scripts.

All the scripts require some environment variables to be set.
1. Export your [GitHub Personal Access Token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) in `GITHUB_OAUTH_TOKEN`.
1. For most use cases, you'll need to export your AWS credentials as the environment variables `AWS_ACCESS_KEY_ID`
and `AWS_SECRET_ACCESS_KEY`.
1. If you're using temporary credentials, which is the case if you're assuming an IAM role, using SAML, or using an MFA token,
also export your `AWS_SESSION_TOKEN`.
1. Start Docker.

Now you're ready to run the scripts via Docker.

_NOTE: Read [this guide](https://blog.gruntwork.io/authenticating-to-aws-with-environment-variables-e793d6f6d02e)_
_for how to authenticate to AWS with environment variables._

[back to readme](README.adoc#running)

## How do I create TLS certs?

To create a TLS cert for your app, the easiest way is to use our provided [docker-compose.yml](docker-compose.yml)
and [Dockerfile](Dockerfile).

1. First make sure you followed [these instructions](#how-do-i-run-these-scripts-using-docker), so that environment
variables are set, and Docker is running.
1. For local development, i.e. **NOT in production**, you can run the following command. Be sure to change the values
to be correct!
    ```sh
    docker-compose run certs \
    --cn acme.com \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme
    ```
    Caveats:
    - The TLS private key will be stored locally unencrypted. We don't recommend this for a production use case.
    - The TLS certificate will not get stored in AWS Secrets Manager, and will not upload to AWS Certificate Manager.
    - However, running the above also doesn't require you to be authenticated with AWS, so `AWS_ACCESS_KEY_ID` and
    `AWS_SECRET_ACCESS_KEY` don't need to be set. <br />

    The cert files will be stored in this folder, under `tls/certs`.
    - `CA.crt`: This is the CA public key, or CA certificate, in PEM format.
    - `app.crt`: This is the app's public key, or TLS certificate, signed by the CA cert, in PEM format.
    - `app.key`: This is the app's TLS private key in PEM format, in plain text.
1. For production use, we recommend using this set of options instead. Be sure to change the values to be correct!
    **Note: You must set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables for this and the
    following examples to work.**
    ```sh
    docker-compose run certs \
    --cn acme.com \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme \
    --aws-region us-east-1 \
    --encrypt-local \
    --kms-key-id alias/dedicated-test-key
    ```
    _We highly recommend including `--encrypt-local` and `--kms-key-id`, along with `--aws-region`, so that you don't
    have an unencrypted private key on your system._

    The script will encrypt the TLS cert's private key, save it as `app.key.kms.encrypted`, and delete the unencrypted
    `app.key`.

    The generated cert files will be stored in this folder, under `tls/certs`.
    - `CA.crt`: The CA public key, or CA certificate, in PEM format.
    - `app.crt`: The app's public key, or TLS certificate, signed by the CA cert, in PEM format.
    - `app.key.kms.encrypted`: The app's TLS private key in PEM format, encrypted with `--kms-key-id`.
    - If you see `app.key`, the script was not able to encrypt your private key using the KMS key you provided (or you
    didn't provide a key), so this is the private key in PEM format, in plain text.
1. Optionally, you can store the cert as a secret in AWS Secrets Manager using `--store-in-sm` and `--secret-name`, in
the region specified by `--aws-region`.
    ```sh
    docker-compose run certs \
    --cn acme.com \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme \
    --store-in-sm \
    --secret-name my-tls-secret \
    --aws-region us-east-1 \
    --kms-key-id alias/dedicated-test-key
    ```
1. Optionally, you can also upload the certificate to ACM using `--upload-to-acm`, in the region specified by
`--aws-region`. If you don't provide a key, AWS Secrets Manager will use your default CMK.

    Note that although creating and operating private CAs using AWS Certificate Manager costs you money, _uploading_ your
    own self-signed certificates to ACM is free.
    ```sh
    docker-compose run certs \
    --cn acme.com \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme \
    --upload-to-acm \
    --aws-region us-east-1
    ```
1. To take full advantage of all the options, including local encryption, AWS Secrets Manager, and AWS Certificate
Manager, you'd run:
    ```sh
    docker-compose run certs \
    --cn acme.com \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme \
    --store-in-sm \
    --secret-name my-tls-secret \
    --upload-to-acm \
    --encrypt-local \
    --aws-region us-east-1 \
    --kms-key-id alias/dedicated-test-key
    ```

[back to readme](README.adoc#running)

## How do I download CA public keys for validating RDS TLS connections?

1. First make sure you followed [these instructions](#how-do-i-run-these-scripts-using-docker), so that environment
variables are set, and Docker is running.
1. Run the following command (which calls [download-rds-ca-certs.sh](download-rds-ca-certs.sh)):
    ```sh
    docker-compose run rds tls/rds-cert
    ```
1. Check `tls/` in the current directory for a file named `rds-cert`. This is the downloaded file.

[back to readme](README.adoc#running)

## How do I generate key stores and trust stores to manage TLS certificates for JVM apps?

1. First make sure you followed [these instructions](#how-do-i-run-these-scripts-using-docker), so that environment
variables are set, and Docker is running.
1. If you don't want to store your key store password in AWS Secrets Manager, run the following command
(which calls [generate-trust-stores.sh](generate-trust-stores.sh)). Be sure to change the values to be correct!
    ```sh
    docker-compose run trust-stores \
    --keystore-name kafka \
    --store-path /tls/trust-stores \
    --vpc-name default \
    --company-name Acme \
    --company-org-unit IT \
    --company-city Phoenix \
    --company-state AZ \
    --company-country US \
    ```
1. If you do want to store the password in AWS Secrets Manager, add the optional arguments `--secret-name`,
`--kms-key-id`, and `--aws-region`:
    ```sh
    docker-compose run trust-stores \
    --keystore-name kafka \
    --store-path /tls/trust-stores \
    --vpc-name default \
    --company-name Acme \
    --company-org-unit IT \
    --company-city Phoenix \
    --company-state AZ \
    --company-country US \
    --secret-name my-trust-stores-secret \
    --kms-key-id alias/dedicated-test-key \
    --aws-region us-east-1
    ```
1. Check `tls/trust-stores/` in the current directory for all your created files:
- `kafka.server.ca.default.pem`
- `kafka.server.cert.default.pem`
- `keystore/kafka.server.keystore.default.jks`
- `truststore/kafka.server.truststore.default.jks`

[back to readme](README.adoc#running)

## How do I test these scripts using Docker?

If you're just using the scripts to create certs, you can skip this section. Otherwise, if you're modifying these scripts, read on!

### Setup
1. First make sure you followed [these instructions](#how-do-i-run-these-scripts-using-docker), so that environment
variables are set, and Docker is running.
1. Run `export TLS_SCRIPTS_KMS_KEY_ID=[your-key-name]`, setting it to the ID of the CMK to use for encryption.
This value can be a globally unique identifier (e.g. `12345678-1234-1234-1234-123456789012`), a fully specified ARN
(e.g. `arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012`), or an alias name prefixed by
`alias/` (e.g. `alias/MyAliasName`).
1. Run `export TLS_SCRIPTS_AWS_REGION=[your-key-region]`, setting it to the AWS region where the KMS key is located
(e.g. `us-east-1`). This is also the region that will be used to upload certs to AWS Certificate Manager and
store secrets in AWS Secrets Manager.

### Test
1. Okay, now you're ready to run the test suite in the [test file](../../test/tls_scripts_test.go).
    ```sh
    # Assuming you're in this directory:
    cd ../../test
    go test -v -run TestTlsScripts
    ```
1. This command will build and run a docker container for each of the tests, just the same way that you would
run the scripts outside of testing.
1. The tests do their own cleanup, so you will not see files created in your system, but the tests should pass.

[back to readme](README.adoc#testing)

## How do I use these certs with my apps?

Using these certs with your app involves providing them to the app process that will serve HTTPS (a web server) so that the server can use them to set up secure connections with clients.

There are two options for providing the certs generated by this app:

1. Write them to a path that your web server will read them from when starting up
2. Store them in AWS Secrets Manager, and have your app fetch them via the AWS API

Let's explore these one at a time.

### Using local certificates to serve content over HTTPS
First, [use the TLS Scripts module to generate our self-signed certificates locally](#how-do-i-create-tls-certs).

Second, if you encrypted your cert on disk, which you should always do for production use cases, you'll need to decrypt it first. We recommend storing the decrypted result in [`tmpfs`](https://man7.org/linux/man-pages/man5/tmpfs.5.html), which is a virtual filesystem that remains in memory and therefore does not carry with it the same risks of writing your secrets to disk.

Now that the private key is unencrypted, either because you decrypted it, or because this is a TLS cert solely-used for local dev and wasn't encrypted in the first place, you should have the following files on disk (run `tree tls` in your working copy of `aws-service-catalog/modules/tls-scripts` to confirm):

```
tls
└── certs
    ├── app.crt
    ├── app.key
    └── CA.crt

1 directory, 3 files
```

Next, you're going to configure your HTTPS serving process to find the newly generated self-signed certificates.

Your app might employ any number of web servers, from [Nginx](https://www.nginx.com) or [Apache](https://www.apache.org), to the standard library HTTPS functionality available in [Node.js](https://nodejs.org/api/https.html) or [Golang](https://golang.org/pkg/net/http/#ListenAndServeTLS).

The exact configurations differ slightly depending on the web server you are using, so we'll share a couple of examples next, but the common thread amongst most servers is that you must specify the path where your server can find the expected keys and certificates (which, in our curent example, is `./tls/certs/<filename>`).

We're now going to step through a sampling of major web servers / languages and configure them to use our the self-signed certificates we just generated. **N.B: the following examples are intended to demonstrate how to use self-signed certificates with common servers, but are not recommended best-practices for running in production!**

Our examples for serving HTTPS traffic using self-signed certificates will be:
* [nginx](#nginx)
* [node.js](#nodejs)
* [golang](#golang)


#### Nginx

[Nginx](https://www.nginx.com) is a popular web server and reverse proxy that is production ready and highly scalable.

* [Install Nginx](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/)
* `sudo touch /usr/share/nginx/example.conf`
* Write the following contents to your new `/usr/share/nginx/example.conf` file:
```
events {}

http {

    server {
        listen              8443 ssl default_server;
        server_name         www.my-example-app.com;

        # Begin SSL configuratioon
        ssl on;
        # We are telling nginx to use the app.crt and app.key to serve traffic over HTTPS
        ssl_certificate     ./tls/certs/app.crt;
        ssl_certificate_key ./tls/certs/app.key;
        ssl_protocols       TLSv1.2;
        ssl_ciphers         HIGH:!aNULL:!MD5;
    }
}
```
* Verify your new nginx config looks good: `sudo nginx -t -c example.conf`. You should see the following output:

```
nginx: the configuration file /usr/share/nginx/example.conf syntax is ok
nginx: configuration file /usr/share/nginx/example.conf test is successful
```
* Copy your locally generated certs to the nginx directory so that nginx can find them when starting up: `sudo cp -R tls/ /usr/share/nginx/tls`
* Because this folder will contain our private key, we want the directory to be owned by root and only readable by that user. Nginx starts up as root prior to spawning the individual nginx worker processes:
    * `sudo chown -R root:root /usr/share/nginx/tls`
    * `sudo chmod -R 600 /usr/share/nginx/tls`
* In our `example.conf` we specified a listening port of `8443`, so ensure you don't already have anything listening on that port!
* Run nginx, specifying that it should use the `example.conf` file: `sudo nginx -c example.conf`
* The previous command should return no output, indicating success. You can also verify that nginx is running locally: `ps -ef | grep nginx`
* You should see similar output to the following:
```
root     25527     1  0 10:01 ?        00:00:00 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
www-data 25530 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25532 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25534 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25537 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25539 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25541 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25542 25527  0 10:01 ?        00:00:00 nginx: worker process
www-data 25543 25527  0 10:01 ?        00:00:00 nginx: worker process
root     27554  3049  0 10:10 ?        00:00:00 nginx: master process nginx -c example.conf`
```

**Verifying everything worked**
* Visit `https://localhost:8443` in your browser. You will receive the errors specified in [the guide to working with self-signed certificates locally](#Working-with-private-self-signed-tls-certificates). Tell your browser to ignore the SSL error as indicated in this guide.
* You should now see the welcome to Nginx page, serving traffic locally over SSL using your self-signed certificates!
![nginx serving HTTPS locally with self-signed certificates](../../_docs/nginx-local-ssl-example.png)

#### Node.js

The following example demonstrates configuring an HTTPS server using [express.js](https://expressjs.com/) in [node.js](https://nodejs.org/en/) with the standard library.

In this example, the certificate authority's public key (`CA.crt`), app's private key (`app.key`) and the app's public key (`app.crt`) are all read from disk via `fs.readFileSync` and passed into the HTTPS server via an object configuring its options.

* [Install node.js](https://nodejs.org/en/download/package-manager/)
* `touch node-ssl.js`
* Write the following contents to `node-ssl.js`
```
fs = require("fs");
path = require("path");
https = require("https");
httpsPort = 8443;
host = "127.0.0.1";

/**
 * Create an HTTPS server by supplying the paths to the TLS secrets
 */
const startHttpsServer = (exports.startHttpsServer = () => {
  console.log(`Starting HTTPS server on host ${host} port ${httpsPort}`);

  // Load the TLS certs by reading them from their paths:
  //
  // Note that in this example our certs exist in ./tls/certs
  //
  // - CA.crt: The Certificate Authority (CA) public key
  // - app.crt: The public key for the app's TLS cert, signed by the CA
  // - app.key: The private key for the app's TLS cert
  const httpsOptions = {
    ca: fs.readFileSync(path.join("tls", "certs", "CA.crt")),
    key: fs.readFileSync(path.join("tls", "certs", "app.key")),
    cert: fs.readFileSync(path.join("tls", "certs", "app.crt")),
  };

  const httpsServer = (exports.httpsServer = https.createServer(
    httpsOptions,
    (req, res) => {
      res.writeHead(200);
      res.end("Hello World over HTTPS!\n");
    }
  ));

  httpsServer.listen(httpsPort, host, () =>
    console.log(`my example app listening on https://${host}:${httpsPort}!`)
  );

  return httpsServer;
});

startHttpsServer();
```
* This example is hardcoded to use port `8443` as port to listen on, so ensure nothing else is listening on that port!
* Start the server with `sudo node node-ssl.js`
* You should see the following output:
```
Starting HTTPS server on host 127.0.0.1 port 8443
my example app listening on https://127.0.0.1:8443!
```
**Verifying everything worked**
* Visit `https://localhost:8443` in your browser. You will receive the errors specified in [the guide to working with self-signed certificates locally](#Working-with-private-self-signed-tls-certificates). Tell your browser to ignore the SSL error as indicated in this guide.
* You should see the output `"Hello world over HTTPS!"`

#### Golang

Let's now set up a simple HTTPS server using the standard library in Golang and our self-signed cerificates.

* [Install Golang](https://golang.org/doc/install)
* `touch go-ssl.go`
* Write the following contents to `go-ssl.go`:
```
package main

import (
    "fmt"
    "io"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, req *http.Request) {
        io.WriteString(w, "Hello, over HTTPS!\n")
    })

    fmt.Println("Server listening on 8443. Go to https://127.0.0.1:8443")
    err := http.ListenAndServeTLS(":8443", "./tls/certs/app.crt", "./tls/certs/app.key", nil)
    fmt.Println(err)
}
```
* This example listens on port `8443`, so ensure you don't already have something listening on that port!
* Build and run the Go program with the following single command `go run go-ssl.go`
* You should see the following output:
```
Server listening on 8443. Go to https://127.0.0.1:8443
```

In this example, we've used the Golang stdlib to create an HTTPS web server, where the desired port to listen on for HTTPS traffic, the app's public key (`app.crt`), and the app's private key (`app.key`) are passed into the [`http.ListenAndServeTLS`](https://golang.org/pkg/net/http/#ListenAndServeTLS) function.

**Verifying everything worked**
 Visit `https://localhost:8443` in your browser. You will receive the errors specified in [the guide to working with self-signed certificates locally](#Working-with-private-self-signed-tls-certificates). Tell your browser to ignore the SSL error as indicated in this guide.
* You should see the output `"Hello, over HTTPS!"`

[back to readme](README.adoc#operate)

## Fetching remote certificates from AWS Secrets manager

### Why use a remote secrets store?

We recommend that you *never* store any secrets, such as app or certificate authority private keys, on disk or in version control in plaintext, as this could lead to them becoming compromised.

Instead, always ensure your TLS certs are encrypted on disk and only decrypted to plaintext, perhaps to an in-memory virtual filesystem such as `tmpfs`, when the app server is booting up.

For a deeper dive into best practices for managing secrets for your apps, see [this guide](https://github.com/gruntwork-io/aws-sample-app/blob/master/core-concepts.md#managing-secrets).

For staging and production *we strongly recommend* the use of a production-grade secrets store such as [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/).

### Using AWS Secrets Manager
[AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) allows you to store arbitrary text. We recommend storing your secrets in a format that's easy to parse programmatically, such as JSON.

The TLS scripts module allows you to optionally store the self-signed certificates it generates in AWS Secrets Manager. Here's how to store your generated certs in AWS Secrets Manager when running this module:

```
docker-compose run certs \
    --country US
    --state AZ \
    --city Phoenix \
    --org Acme \
    --secret-name my-tls-secret \
    --aws-region us-east-1 \
    --kms-key-id alias/dedicated-test-key
```

Note that AWS Secrets Manager optionally allows you to specify an [AWS Customer Managed Key](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html) (CMK) that will be used to encrypt your secret. The `--kms-key-id` flag accepts **either** a KMS key ID or the [alias](https://docs.aws.amazon.com/kms/latest/developerguide/programming-aliases.html) of an existing KMS key, mirroring the behavior of AWS Secrets Manager. In the above example, we pass `--kms-key-id alias/dedicated-test-key`

However, if you do not provide this key ID, then AWS Secret Manager's default behavior is to create new key and use it to encrypt your secret data.

The TLS scripts module accomodates both use cases, by allowing you to optionally provide the ID fo the KMS key you want to use for encryption via the optional `--kms-key-id` flag, or omit this flag entirely, in which case AWS Secrets Manager will generate a key for you when encrypting your secret.

### Verifying your TLS Secrets in AWS Secrets Manager

The TLS scripts module puts the:

* certificate authority's public key
* app's public key
* app's private key

into a single JSON object and stores it as one secret in AWS Secrets Manager for greater ease of use. This allows us to fetch all 3 TLS Secrets whenever we need them with a single API call.

Here's what the resulting secret will look like in AWS Secrets Manager:

```
{
  "app": {
    "crt": "-----BEGIN CERTIFICATE-----\nMIIDbDCCAlSgAwIBAgIUKSmnaNqgmS7ZTlf3cz1lmMaNK4MwDQYJKoZIhvcNAQEL\nBQAwVzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkFaMRAwDgYDVQQHDAdQaG9lbml4\nMRIwEAYDVQQKDAlHcnVudHdvcmsxFTATBgNVBAMMDGdydW50d29yay1jYTAeFw0y\nMDAzMTQxOTQxMTVaFw0yMTA3MjcxOTQxMTVaMFIxCzAJBgNVBAYTAlVTMQswCQYD\nVQQIDAJBWjEQMA4GA1UEBwwHUGhvZW5peDESMBAGA1UECgwJR3J1bnR3b3JrMRAw\nDgYDVQQDDAdiYWNrZW5kMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\ny1Fpf3awyrnRbJMUZPhwSR8ZPgQ7BtyTVWFqh3Nazxf5r6DT3WUXOh7p2z3S+fMh\nakTbBbesdOCg8U5rU7oCBqDbFMw6DNkhSe2EzZYksyMa6G1W5kLHqoEdUdPJWmTW\ng1vbfxqn/MKXWAZCQnHsiX/QWyVn2fgYOBS2xDrnWF4wQq85LVmJxpnpAkiyN7tl\nWBn5t3cs/+T+XZ7mhtRwGdOCZ8/dYRfFcdX/0i0Y1qebKE7akMlbLipONwrqXIO0\nkThy7En7OWPRkXUvmNBF46m2uPwY0St25LoCJ9sBVJWTGbwC5Iv3DC3cIcRaaItv\nXK3n1kpxSiBz7qAIF3nNQQIDAQABozUwMzAjBgNVHREEHDAaggdiYWNrZW5kggls\nb2NhbGhvc3SHBH8AAAEwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEA\nUVF0Ltic1B6zDPvinxOBLjlIaBo+mM926B9OtH9kmLV6J04CcIV7VtcVXqpLPVQe\nNAqyRi9Mri11uBE35fy7hQTosT6oj8kqrDMDavQ8jdLP68NinUuDHawU4SOy69If\nTNDtIaVaCfOcwgaexDj+u7JJKWJPGA8KGt29TURvKFVgGxe++3Tw9CcAfEZ2CX2g\nIOnpXCYoymZX7B//w0zFPsLd9U/pvhk35Xr6E16qvKW3ZSmva8t3yfR4Gdf3U1nJ\nyif8udMn1fYVaax8Qk8uch3mj+5LV5BxskBK4XViUq2nBqI6o6pySHtAmk2pFR32\nx2oNDO+6i39xYYvvtjVGgg==\n-----END CERTIFICATE-----\n",
    "key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDLUWl/drDKudFs\nkxRk+HBJHxk+BDsG3JNVYWqHc1rPF/mvoNPdZRc6HunbPdL58yFqRNsFt6x04KDx\nTmtTugIGoNsUzDoM2SFJ7YTNliSzIxrobVbmQseqgR1R08laZNaDW9t/Gqf8wpdY\nBkJCceyJf9BbJWfZ+Bg4FLbEOudYXjBCrzktWYnGmekCSLI3u2VYGfm3dyz/5P5d\nnuaG1HAZ04Jnz91hF8Vx1f/SLRjWp5soTtqQyVsuKk43Cupcg7SROHLsSfs5Y9GR\ndS+Y0EXjqba4/BjRK3bkugIn2wFUlZMZvALki/cMLdwhxFpoi29crefWSnFKIHPu\noAgXec1BAgMBAAECggEAXNcyG1gxZoDvVmra9zhS3bDrr9vysDFsvaIcKPnNz58d\nDsubsw8ESi/vjYNvoV8aNRJ4COZUQ5KHK2kprTPU1P4CzD5ti4xinQVujQowe/Rd\nxyCWe9Kmpf8LSmAxI6vEIHuDgUjEyLB6t2E0RG8NGcRZeiVchLW7KXCb/IMBPOIF\nGyiWIGt871HCRMKmO8afxmq+FWknQwwjPZkndtJ2+ruopTm1HpoBMNiYS3f1nHuT\nsdsvPC83U6kBs0nIx5j4QFOTOv/Fen9aQ03b2jQE7WGYy1tVr5AE+bguDjD4xnrR\nCgdIV4NagYHuPonyoxJeu4FMLp8sPg+sBDIDoRKgGQKBgQDs0pD1/Wtc5Lkh99vl\nGGeeaswq4J322zVAPrZmEYr3FE/MslG97QL2pd2pUL30esMOsUVzAfgbogVDbOWj\nVKAzOKOO0AMdq06rdq3uWYwr3GdRslCjjOtCaOIdbdz/xJ7dNEm69Y1+QMYtcCGY\nODhL0HuAwBm1kHLdBa+HqxnIZwKBgQDbyEhoX5CUBlkkVLiRZETGw5ruMtCvfqrL\ntRqE31hx17nHddycuNCqOlL4j21Rulc196dYIY5oduAiEoDgtTzmf+qX2e/qAgoX\nCw3jMvuizUF8giSzH+WgRZksnWT+Q9mPppXuxb9FgwxBNdE3V3GybMSD3U8TuQdX\nijC2dgFUFwKBgQCpVs/M9c6ld+9heKhGIrNFNbyUFFUfxRNIww8N4RFrJ50AE6ob\nkrSBxYzAmzmY7Yc4pE2ytP/CUpJM6jsyFTsQJTnezqLLvkjcllo8is+ONWWzpzu+\nFu/KZtD4lixmvyORrOfjxd3NH2gV6Y48GEc4/vSw1awMhiN8I6ql6hTflQKBgHtO\nnhk47KOwABlbEwY3bELcAbN8fQrJFUge/pbnu/Z7IvceUDz5j9DB0kU0KxA8bKuR\nm6jdgslnUI6tNPNdm6JyyAqUMn9mz4RoJk1/ECEh6YjSd4ar8af/BFY8pCnnpUts\nGhiRh6OXR6vaZtwWymphjcuxwaj+GXlqxbPI9yvXAoGAcL4xwOlncSi+KnJU0edd\nNhrbnvY5gm2HezX+Z6d4NIYPQ843lWpvYUI7Pg7clgmJlfMkZLLvtp08lDcgan/m\nZxoWjJRPW7K0b6kPWjq2z4DYkzk5ApLWfCH2ZploZGBt0Oycq4wYql4Un8YRSoOT\nipaGhxyX03Fse391t2t/Ys4=\n-----END PRIVATE KEY-----\n",
    "ca": "-----BEGIN CERTIFICATE-----\nMIIDjzCCAnegAwIBAgIUF1zRCLbaRCACZJre/MuVPMxGUTEwDQYJKoZIhvcNAQEL\nBQAwVzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkFaMRAwDgYDVQQHDAdQaG9lbml4\nMRIwEAYDVQQKDAlHcnVudHdvcmsxFTATBgNVBAMMDGdydW50d29yay1jYTAeFw0y\nMDAzMTQxOTQxMTVaFw0yMTA3MjcxOTQxMTVaMFcxCzAJBgNVBAYTAlVTMQswCQYD\nVQQIDAJBWjEQMA4GA1UEBwwHUGhvZW5peDESMBAGA1UECgwJR3J1bnR3b3JrMRUw\nEwYDVQQDDAxncnVudHdvcmstY2EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\nAoIBAQDQcea/YH/TR2eBnwZLQETReydD1Om2jiyBGs3ABagAvi+58pZnJ3L9BI9l\nLowWtm8aMV0Vq6PW4gkUj6SHfiNYDQYXQUNVZSpT1x2VMjWhgxpKrLbbLXWKcBvg\nk3XWHzINqvIsl1sILvfPaBGgE/8OZcWLLOpeWnoo9nDXu3Wj91/vfsq1JOwesUJW\n49H2Lgz2kdS59hsl1syfmZf7+eFeQyEfEymeKzRLTFhpwdmfimw5moQt27hXnv96\nDCzDPPAKWYAXyQfGhP/x4olkACHFJ24MOv3OkMhsOKOCQbyYJS8UdNQnX/6ZYHvg\n5cfgUNIvti1wXiyrqO6m4IJNa1c5AgMBAAGjUzBRMB0GA1UdDgQWBBTsjHfEKghg\nRJT59L7nmt4IAsAhcjAfBgNVHSMEGDAWgBTsjHfEKghgRJT59L7nmt4IAsAhcjAP\nBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQC93U3DvG9q8GKbJLfM\nvpCcc+De94b+kqMwpAL0ezOCfqnAmFVITG5cUWdTLZHKvMXwfu8gnvBB8ht3pBBl\nrSMdAvGXZQSKZLV95V+Ur1OOgVAicL9gSTxOtyNdTZ/X4ZBY/bdW2p59joBN/ew3\nU3kJDocsd7xPROVd816+XcD+YeerU8Xn2rLbj2eC0B2uXFwpBrgSKot1Rezl1g5R\nh9eQAJW1rKHR8+yxRgPpz59IEB2ogQ+LYBIq6oOUjie6LTeXiBUUEpgfSVByXIGa\nosc1yG7j9/DsZo9+qjlt/OcP5m48eku34P8HMo/XNHHR5iLL/255BR573Lsx0xvg\nl5IC\n-----END CERTIFICATE-----\n"
  }
}

```

Your apps can now fetch this secret from AWS Secrets Manager and process the JSON to retrieve the keys and certificates as needed.

Let's take a look at how to do that now.

#### Fetch TLS secrets from AWS Secrets Manager

With our TLS secrets stored in AWS Secrets Manager, we now need our app to fetch them via the AWS API so that it can use them to serve encrypted traffic over HTTPS.

Note that, before your app can fetch secrets from AWS Secrets Manager, it must have the proper IAM permissions to do so. We can use Terraform to create the correct IAM polciy and role.

The following code creates an IAM policy that allows for reading of the specific secret, and then attaches this policy to an IAM role that will be attached to your app (i.e., attached to the ECS Task, or EKS Pod, or ASG):

    ```hcl
    resource "aws_iam_role_policy" "read_secrets_manager_secret" {
      name   = "read-secrets-manager-secret"
      # This should reference an IAM role accessible to your app
      role   = var.iam_role_id
      policy = data.aws_iam_policy_document.read_secrets_manager_secret.json
    }

    data "aws_iam_policy_document" "read_secrets_manager_secret" {
      statement {
        effect    = "Allow"
        actions   = ["secretsmanager:GetSecretValue"]
        # Make sure to replace this ARN with the ARN of the secret you created in AWS Secrets Manager
        resources = ["arn:aws:secretsmanager:<region>:<account-id>:secret:my-db-config-<unique-id>"]
      }
    }
    ```

With permissions in place, your app can now make a request to AWS Secrets Manager for the secret it needs. How and when you actually retrieve the secret is up to you. You could do it via a bash script at startup, or make an API call in Node prior to starting up your HTTPS web server.

 Here's an example of doing so in bash. If your app were running in a Docker container, for example, you might have this function in a bash script that is set as the [Entrypoint](https://docs.docker.com/engine/reference/builder/#entrypoint):

```
# Returns the raw value of a secret string stored in AWS Secrets Manager.
function read_secret_from_aws_secrets_manager {
  local -r environment_name="$1"
  local -r aws_region="$2"
  local -r secret_id="$3"

  log_info "Reading secret '$secret_id' from AWS Secrets Manager in $aws_region"

  # Use '--output text' to avoid having Secrets Manager escape any of the characters in the secret value. E.g., If the
  # secret value contained JSON and '--output json' was set instead, then all the double quoutes would be escaped in
  # the resulting output.
  aws secretsmanager get-secret-value \
    --region "$aws_region" \
    --secret-id "$secret_id" \
    --output text \
    --query 'SecretString'
}
```

In the above example, we're using the [AWS CLI](https://aws.amazon.com/cli/) to fetch the secret from AWS Secrets Manager.

Keeping the secret in JSON as discussed earlier allows us to make only a single API call to get everything we need from the remote secret store.

Since the above call returns a JSON object containing all of our TLS secrets, we'll need to process the JSON in order to retrieve the individual keys and certificates as needed. Here's some sample bash demonstrating how to do that using [the jq command line tool](https://stedolan.github.io/jq/) for processing JSON:

```
local -r secret_output
local -r ca_public_key
local -r app_public_key
local -r app_private_key

# Note that we're calling the bash function shown above to get our secret out of AWS Secrets Manager
# which in this case is a JSON object containing all our TLS secrets
secret_output=$(read_secret_from_aws_secrets_manager "dev" "us-east-1" "my-tls-secret")

# $secret_output now contains the JSON object that we stored in AWS Secrets Manager
# so we can use the JSON parsing tool jq to extract the individual keys and certificates

# fetch the value of the "ca" field nested under the "app" object in our JSON
$ca_public_key=$(echo "$secret_output" | jq .app.ca)

# fetch the value of the "crt" field nested under the "app" object in our JSON
$app_public_key=$(echo "$secret_output" | jq .app.crt)

# fetch the value of the "key" field nested under the "app" object in our JSON
$app_private_key=$(echo "$secret_output" | jq .app.key)

```

With your TLS secrets now extracted, you could now write them to `tmpfs`, a virtual filesystem that stores everything in memory and does not persist anything to disk. At that point, you just provide the paths to your web server as illustrated in the examples above.

[back to readme](README.adoc#operate)

### Working with private, self-signed TLS certificates

While your web browser and other HTTP clients will automatically be able to verify and trust certificates signed by
public, well-known CAs, such as Let's Encrypt and Amazon, those tools will NOT automatically trust certificates signed
by private CAs (self-signed certs). If your app is using a self-signed TLS certificate and you try to access it over
HTTPS, you'll see an error like this:

![Self-signed cert TLS error](../../_docs/tls-error.png)

Similarly, if you try to use `curl`, you'll get an error like this:

```
$ curl https://localhost:8443
curl: (60) SSL certificate problem: self signed certificate in certificate chain
More details here: https://curl.haxx.se/docs/sslcerts.html
```

In the local dev environment, it's OK to ignore this error, as you know that it's a self-signed cert the app generated
for itself, and you can trust it. In Chrome, you can tell the browser to ignore the error by clicking the "Advanced"
button and then the "Proceed to localhost" link:

![Ignoring the self-signed cert TLS error](../../_docs/tls-error-ignore.png)

Similarly, you can tell `curl`  to ignore the error using the `-k` flag:

```
$ curl -k https://localhost:8443
```

In all other environments, you'll want to get access to the CA public key to validate the certificate. In the local dev
environment, the CA public key is copied to `tls/CA-<app_name>.crt` (e.g., `tls/CA-frontend.crt`).

The instructions for getting your browser to trust it depend on the browser and OS, so do a Google search: e.g., in
Chrome, you can go to Settings -> Manage certificates and add a certificate in the window that pops up.

For `curl`, it's simpler, as you just pass the cert in via the `--cacert` argument. For example:

```bash
curl --cacert ../tls/my-ca.crt https://localhost:8443
```

[back to readme](README.adoc#operate)
