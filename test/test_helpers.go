package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

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
