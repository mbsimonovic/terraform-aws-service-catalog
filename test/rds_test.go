package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestRDS(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/rds")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

		dbPassword := fmt.Sprintf("%s-%s", random.UniqueId(), random.UniqueId())
		test_structure.SaveString(t, testFolder, "password", dbPassword)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		dbPassword := test_structure.LoadString(t, testFolder, "password")

		terraformOptions := createRDSTerraformOptions(t, testFolder, awsRegion, uniqueID, dbPassword)
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		dbName := "rds"
		dbUsername := "rds"
		dbPassword := test_structure.LoadString(t, testFolder, "password")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		dbEndpoint := terraform.OutputRequired(t, terraformOptions, "primary_endpoint")
		dbPort := terraform.OutputRequired(t, terraformOptions, "port")

		info := RDSInfo{
			Username:   dbUsername,
			Password:   dbPassword,
			DBName:     dbName,
			DBEndpoint: dbEndpoint,
			DBPort:     dbPort,
		}
		smokeTestMysql(t, info)
	})
}

func createRDSTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
	password string,
) *terraform.Options {
	name := fmt.Sprintf("test-rds-%s", uniqueID)
	terraformOptions := createBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["name"] = name
	terraformOptions.Vars["db_name"] = "rds"
	terraformOptions.Vars["master_username"] = "rds"
	terraformOptions.Vars["master_password"] = password
	terraformOptions.Vars["share_snapshot_with_account_id"] = getExternalAccountId()
	return terraformOptions
}
