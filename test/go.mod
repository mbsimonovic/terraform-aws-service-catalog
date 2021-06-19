module github.com/gruntwork-io/aws-service-catalog/test

go 1.14

require (
	github.com/aws/aws-sdk-go v1.38.28
	github.com/go-sql-driver/mysql v1.5.0
	github.com/gruntwork-io/gruntwork-cli v0.7.0
	github.com/gruntwork-io/module-ci/test/edrhelpers v0.0.0-20200930113208-063f02f8ef67
	github.com/gruntwork-io/terratest v0.36.0
	github.com/mattn/go-zglob v0.0.2-0.20190814121620-e3c945676326
	github.com/stretchr/testify v1.6.1
	k8s.io/api v0.19.3
	k8s.io/apimachinery v0.19.3
)

replace github.com/gruntwork-io/module-ci/modules/infrastructure-deployer => github.com/gruntwork-io/module-ci/modules/infrastructure-deployer v0.0.0-20200930113208-063f02f8ef67
