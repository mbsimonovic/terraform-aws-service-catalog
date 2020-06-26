package test

import (
	//"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestPublicStaticWebsite(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "us-east-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

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
	})
}

func createStaticWebsiteTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
) *terraform.Options {
	terraformOptions := createBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["hosted_zone_id"] = "Z2AJ7S3R6G9UYJ"
	terraformOptions.Vars["aws_region"] = "us-east-1"
	terraformOptions.Vars["aws_account_id"] = "087285199408"
	terraformOptions.Vars["website_domain_name"] = "acme-stage.gruntwork.in"
	terraformOptions.Vars["terraform_state_aws_region"] = "us-east-1"
	terraformOptions.Vars["terraform_state_s3_bucket"] = "acme-test-static-website_state"
	terraformOptions.Vars["acm_certificate_domain_name"] = "*.gruntwork.in"
	return terraformOptions
}
