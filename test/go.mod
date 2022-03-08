module github.com/gruntwork-io/aws-service-catalog/test

go 1.14

require (
	github.com/aws/aws-sdk-go v1.43.12
	github.com/go-sql-driver/mysql v1.6.0
	github.com/gruntwork-io/go-commons v0.11.0
	github.com/gruntwork-io/module-ci/test/edrhelpers v0.0.0-20220304223529-26f4f52e03fb
	github.com/gruntwork-io/terratest v0.40.6
	github.com/mattn/go-zglob v0.0.3
	github.com/stretchr/testify v1.7.0
	k8s.io/api v0.20.6
	k8s.io/apimachinery v0.20.6
)

replace github.com/gruntwork-io/module-ci/modules/infrastructure-deployer => github.com/gruntwork-io/module-ci/modules/infrastructure-deployer v0.0.0-20220304223529-26f4f52e03fb
