package data_stores

import (
	"fmt"
	"github.com/gruntwork-io/aws-service-catalog/test"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestRedis(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "us-west-2")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/redis")

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

		terraformOptions := createRedisTerraformOptions(t, testFolder, awsRegion, uniqueID)
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.OutputRequired(t, terraformOptions, "primary_endpoint")
		terraform.OutputRequired(t, terraformOptions, "cache_port")
	})
}

func createRedisTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
) *terraform.Options {
	name := fmt.Sprintf("test-redis-%s", uniqueID)
	terraformOptions := test.CreateBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["name"] = name
	return terraformOptions
}
