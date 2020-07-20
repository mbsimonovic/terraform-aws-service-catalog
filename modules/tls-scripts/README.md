# TLS scripts

This folder contains several Bash scripts that simplify working with TLS certificates. You will typically only need 
these scripts to configure end-to-end encryption in your Reference Architecture.  

- `create-tls-cert.sh`: This script will automatically create a CA cert and a TLS cert signed by that CA, assuming
   those certs don't already exist. The TLS cert private key will be encrypted with gruntkms. Optionally, this script 
   can also upload the cert to IAM, so it can be used with an ELB or ALB. These certs are meant for private/internal 
   use only, such as to set up end-to-end encryption within an AWS account. The only IP address in the cert will be 
   127.0.0.1 and localhost, so you can test your servers locally. You can also use the servers with the ELB or ALB, as 
   the AWS load balancers don't verify the CA.

- `generate-trust-stores.sh`: This script is meant to be used to automatically generate a Key Store and Trust Store, 
   which are typically used with Java apps to securely store SSL certificates. If they don't already exist, the Key 
   Store, Trust Store, and public cert / CA will be generated to the specified paths, and the Key Store password will 
   be stored in AWS Secrets Manager. The script writes the KMS-encrypted password for the Key Store to stdout.
   
- `download-rds-ca-certs.sh`: Download the CA certs for RDS so that applications can validate the certs when connecting 
   to RDS over SSL.


## Usage

Check out 
[How to deploy the Reference Architecture from scratch]({{ .GitBaseUrlHttps }}/{{ .InfrastructureLiveRepoName }}/{{ if or (eq .GitRepoType "GitHub") (eq .GitRepoType "GitLab") }}tree/master/{{ else }}browse/{{ end }}_docs/13-deploying-the-reference-architecture-from-scratch.md) for instructions on how and when to use these scripts.
