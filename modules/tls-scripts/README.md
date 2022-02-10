# TLS Scripts

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This folder contains scripts that simplify the process of creating and managing TLS certificates, JVM key stores and trust stores, and RDS CA certificates.

## Features

Bash scripts that simplify working with TLS certificates. You will typically only need
these scripts to configure end-to-end encryption in your Reference Architecture.

- Simplify creating self-signed TLS certificates

- Encrypt TLS certificates using KMS

- Upload TLS certificates to AWS for use with ELBs

- Download CA public keys for validating RDS TLS connections

- Simplify creating key stores and trust stores to manage TLS certificates for JVM apps

- Run from a Docker container so you don’t need to install any dependencies locally

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### About TLS

- [How does TLS/SSL work?](core-concepts.md#how-does-tlsssl-work)

- [What are commercial or public Certificate Authorities?](core-concepts.md#what-are-commercial-or-public-certificate-authorities)

- [How does Gruntwork generate a TLS cert for private services?](core-concepts.md#how-does-gruntwork-generate-a-tls-cert-for-private-services)

### About the scripts specifically

- [How does create-tls-cert work?](core-concepts.md#how-does-create-tls-cert-work)

- [How does download-rds-ca-certs work?](core-concepts.md#how-does-download-rds-ca-certs-work)

- [How does generate-trust-stores work?](core-concepts.md#how-does-generate-trust-stores-work)

## Deploy

### Running

- [How do I run these scripts using Docker?](core-concepts.md#how-do-i-run-these-scripts-using-docker)

- [How do I create self-signed TLS certs?](core-concepts.md#how-do-i-create-self-signed-tls-certs)

- [Should I store certs in AWS Secrets Manager or Amazon Certificate Manager?](core-concepts.md#should-i-store-certs-in-aws-secrets-manager-or-amazon-certificate-manager)

- [Generating self-signed certs for local dev and testing](core-concepts.md#generating-self-signed-certs-for-local-dev-and-testing)

- [Generating self-signed certs for prod, encrypting certs locally with KMS](core-concepts.md#generating-self-signed-certs-for-prod-encrypting-certs-locally-with-kms)

- [Generating self-signed certs for prod, using AWS Secrets Manager for storage](core-concepts.md#generating-self-signed-certs-for-prod-using-aws-secrets-manager-for-storage)

- [Generating self-signed certs for prod, using Amazon Certificate Manager for storage](core-concepts.md#generating-self-signed-certs-for-prod-using-amazon-certificate-manager-for-storage)

- [How do I download CA public keys for validating RDS TLS connections?](core-concepts.md#how-do-i-download-CA-public-keys-for-validating-rds-tls-connections)

- [How do I generate key stores and trust stores to manage TLS certificates for JVM apps?](core-concepts.md#how-do-i-generate-key-stores-and-trust-stores-to-manage-tls-certificates-for-jvm-apps)

### Testing

- [How do I test these scripts using Docker?](core-concepts.md#how-do-i-test-these-scripts-using-docker)

## Operate

- [How do I use these certs with my apps?](core-concepts.md#how-do-i-use-these-certs-with-my-apps)

- [Using local certificates to serve content over HTTPS](core-concepts.md#using-local-certificates-to-serve-content-over-https)

- [An example of using these certs with Nginx](core-concepts.md#nginx)

- [An example of using these certs with Node.js](core-concepts.md#nodejs)

- [An example of using these certs with Golang](core-concepts.md#golang)

- [Fetching certificates from AWS Secrets Manager](core-concepts.md#fetching-remote-certificates-from-aws-secrets-manager)

- [Working with private, self-signed TLS certificates](core-concepts.md#working-with-private-self-signed-tls-certificates)

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure, feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library)
for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
