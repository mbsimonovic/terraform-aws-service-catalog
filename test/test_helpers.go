package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Test constants for the Gruntwork Phx DevOps account
const (
	baseDomainForTest = "gruntwork.in"
	acmDomainForTest  = "*.gruntwork.in"
)

// Regions in Gruntwork Phx DevOps account that have ACM certs
var acmRegionsForTest = []string{
	"us-east-1",
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"eu-central-1",
	"ap-northeast-1",
	"ap-southeast-2",
	"ca-central-1",
}

// Tags in Gruntwork Phx DevOps account to uniquely find Hosted Zone for baseDomainForTest
var domainNameTagsForTest = map[string]interface{}{"original": "true"}

// Some of the tests need to run against Organization root account. This method overrides the default AWS_* environment variables
func configureTerraformForOrgTestAccount(t *testing.T, terraformOptions *terraform.Options) {
	if terraformOptions.EnvVars == nil {
		terraformOptions.EnvVars = map[string]string{}
	}
	terraformOptions.EnvVars["AWS_ACCESS_KEY_ID"] = os.Getenv("AWS_ORGTEST_ACCESS_KEY_ID")
	terraformOptions.EnvVars["AWS_SECRET_ACCESS_KEY"] = os.Getenv("AWS_ORGTEST_SECRET_ACCESS_KEY")
}

func pickNRegions(t *testing.T, count int) []string {
	regions := []string{}
	for i := 0; i < count; i++ {
		region := aws.GetRandomStableRegion(t, nil, regions)
		regions = append(regions, region)
	}
	return regions
}
