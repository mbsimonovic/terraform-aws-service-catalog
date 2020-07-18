package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestPublicStaticWebsite(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_setup", "true")
	// os.Setenv("SKIP_deploy_terraform", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/services/public-static-website")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")

		terraformOptions := createStaticWebsiteTerraformOptions(t, testFolder, awsRegion, uniqueID)
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		terraform.OutputRequired(t, terraformOptions, "cloudfront_domain_names")
		terraform.OutputRequired(t, terraformOptions, "cloudfront_id")
		terraform.OutputRequired(t, terraformOptions, "website_s3_bucket_arn")
		terraform.OutputRequired(t, terraformOptions, "website_access_logs_bucket_arn")
		terraform.OutputRequired(t, terraformOptions, "cloudfront_access_logs_bucket_arn")
		err := http_helper.HttpGetWithRetryWithCustomValidationE(
			t,
			fmt.Sprintf("http://%v", terraformOptions.Vars["website_domain_name"]),
			nil,
			3,
			1,
			func(statusCode int, body string) bool {
				return statusCode == 200 && strings.Contains(body, "example static website")
			},
		)
		require.NoError(t, err)
	})
}

func createStaticWebsiteTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
) *terraform.Options {
	terraformOptions := createBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["aws_region"] = "ap-southeast-1"
	terraformOptions.Vars["aws_account_id"] = "087285199408"
	terraformOptions.Vars["website_domain_name"] = fmt.Sprintf("acme-stage-static-%s.%s", uniqueID, baseDomainForTest)
	terraformOptions.Vars["acm_certificate_domain_name"] = acmDomainForTest
	terraformOptions.Vars["base_domain_name"] = baseDomainForTest
	terraformOptions.Vars["base_domain_name_tags"] = domainNameTagsForTest
	terraformOptions.Vars["force_destroy"] = true
	return terraformOptions
}
