package data_stores

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var (
	regionsThatSupportAuroraServerless = []string{
		"us-east-1",
		"us-east-2",
		"us-west-1",
		"us-west-2",
		"ap-southeast-1",
		"ap-southeast-2",
		"ap-northeast-1",
		"ca-central-1",
		"eu-central-1",
		"eu-west-1",
		"eu-west-2",
		"eu-west-3",
	}
)

func TestAuroraServerless(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/aurora")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		setupAuroraParameters(t, testFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		secretID := test_structure.LoadString(t, testFolder, "secretID")

		terraformOptions := createAuroraTerraformOptions(t, testFolder, awsRegion, uniqueID, secretID)
		terraformOptions.Vars["engine_mode"] = "serverless"
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	// TODO: serverless Aurora can't be publicly exposed, so we need an alternate validation test that hops through a
	// proxy.
}

func TestAuroraCustomParameter(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/aurora")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		setupAuroraParameters(t, testFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		secretID := test_structure.LoadString(t, testFolder, "secretID")

		terraformOptions := createAuroraTerraformOptions(t, testFolder, awsRegion, uniqueID, secretID)
		terraformOptions.Vars["engine"] = "aurora-mysql"
		terraformOptions.Vars["db_cluster_custom_parameter_group"] = map[string]interface{}{
			"name":   fmt.Sprintf("parameter-%s", uniqueID),
			"family": "aurora-mysql5.7",
			"parameters": []map[string]string{
				map[string]string{
					"name":         "lower_case_table_names",
					"value":        "1",
					"apply_method": "pending-reboot",
				},
			},
		}
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})
}

func TestAurora(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/aurora")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)

		awsRegion := test_structure.LoadString(t, testFolder, "region")
		secretID := test_structure.LoadString(t, testFolder, "secretID")
		aws.DeleteSecret(t, awsRegion, secretID, true)
	})

	test_structure.RunTestStage(t, "setup", func() {
		setupAuroraParameters(t, testFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		secretID := test_structure.LoadString(t, testFolder, "secretID")

		terraformOptions := createAuroraTerraformOptions(t, testFolder, awsRegion, uniqueID, secretID)
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		dbName := "aurora"
		dbUsername := "aurora"
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
		SmokeTestMysql(t, info)
	})
}

func createAuroraTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
	dbConfigSecretID string,
) *terraform.Options {
	name := fmt.Sprintf("test-aurora-%s", uniqueID)
	terraformOptions := test.CreateBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["name"] = name
	terraformOptions.Vars["db_config_secrets_manager_id"] = dbConfigSecretID
	terraformOptions.Vars["share_snapshot_with_account_id"] = test.GetExternalAccountId()
	return terraformOptions
}

func setupAuroraParameters(t *testing.T, testFolder string) {
	awsRegion := aws.GetRandomStableRegion(t, regionsThatSupportAuroraServerless, nil)
	test_structure.SaveString(t, testFolder, "region", awsRegion)

	uniqueID := strings.ToLower(random.UniqueId())
	test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

	dbName := "rds"
	dbUsername := "rds"
	dbPassword := fmt.Sprintf("%s-%s", random.UniqueId(), random.UniqueId())

	dbConfig := getDbConfigJSON(t, dbName, dbUsername, dbPassword, "aurora")
	secretID := aws.CreateSecretStringWithDefaultKey(t, awsRegion, "Test description", "test-name-"+uniqueID, dbConfig)
	test_structure.SaveString(t, testFolder, "dbName", dbName)
	test_structure.SaveString(t, testFolder, "username", dbUsername)
	test_structure.SaveString(t, testFolder, "password", dbPassword)
	test_structure.SaveString(t, testFolder, "secretID", secretID)
}
