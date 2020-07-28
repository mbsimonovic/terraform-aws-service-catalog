module github.com/gruntwork-io/aws-service-catalog/test

go 1.13

require (
	github.com/aws/aws-sdk-go v1.27.1
	github.com/go-sql-driver/mysql v1.4.1
	github.com/google/go-github/v32 v32.0.0
	github.com/gruntwork-io/gruntwork-cli v0.6.1

	github.com/gruntwork-io/terratest v0.28.3

	github.com/mattn/go-zglob v0.0.2-0.20190814121620-e3c945676326
	github.com/stretchr/testify v1.5.0
	golang.org/x/oauth2 v0.0.0-20200107190931-bf48bf16ab8d
	k8s.io/api v0.18.3
	k8s.io/apimachinery v0.18.3
)

// TODO: Update based on outcome of https://github.com/gruntwork-io/terratest/pull/578
replace github.com/gruntwork-io/terratest => github.com/gruntwork-io/terratest v0.28.11-0.20200728190946-e3a5c9acd67c
