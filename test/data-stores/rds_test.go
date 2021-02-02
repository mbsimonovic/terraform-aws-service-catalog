package data_stores

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestRds(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "us-west-2")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/rds")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)

		awsRegion := test_structure.LoadString(t, testFolder, "region")
		secretID := test_structure.LoadString(t, testFolder, "secretID")
		aws.DeleteSecret(t, awsRegion, secretID, true)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

		dbName := "rds"
		dbUsername := "rds"
		dbPassword := fmt.Sprintf("%s-%s", random.UniqueId(), random.UniqueId())

		dbConfig := getDbConfigJSON(t, dbName, dbUsername, dbPassword, "mysql")
		secretID := aws.CreateSecretStringWithDefaultKey(t, awsRegion, "Test description", "test-name-"+uniqueID, dbConfig)
		test_structure.SaveString(t, testFolder, "dbName", dbName)
		test_structure.SaveString(t, testFolder, "username", dbUsername)
		test_structure.SaveString(t, testFolder, "password", dbPassword)
		test_structure.SaveString(t, testFolder, "secretID", secretID)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		secretID := test_structure.LoadString(t, testFolder, "secretID")

		terraformOptions := createRDSTerraformOptions(t, testFolder, awsRegion, uniqueID, secretID)
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		dbName := test_structure.LoadString(t, testFolder, "dbName")
		dbUsername := test_structure.LoadString(t, testFolder, "username")
		dbPassword := test_structure.LoadString(t, testFolder, "password")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		dbEndpoint := terraform.OutputRequired(t, terraformOptions, "primary_host")
		dbPort := terraform.OutputRequired(t, terraformOptions, "port")

		info := test.RDSInfo{
			Username:   dbUsername,
			Password:   dbPassword,
			DBName:     dbName,
			DBEndpoint: dbEndpoint,
			DBPort:     dbPort,
		}
		test.SmokeTestMysql(t, info)
	})
}

func createRDSTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
	dbConfigSecretID string,
) *terraform.Options {
	name := fmt.Sprintf("test-rds-%s", uniqueID)
	terraformOptions := test.CreateBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["name"] = name
	terraformOptions.Vars["db_config_secrets_manager_id"] = dbConfigSecretID
	return terraformOptions
}

func getDbConfigJSON(t *testing.T, dbName, username, password, engine string) string {
	type DbConfig struct {
		Engine   string `json:"engine"`
		Username string `json:"username"`
		Password string `json:"password"`
		Dbname   string `json:"dbname"`
		Port     string `json:"port"`
	}

	config := DbConfig{
		Engine:   engine,
		Username: username,
		Password: password,
		Dbname:   dbName,
		Port:     "3306",
	}

	result, err := json.Marshal(config)
	require.NoError(t, err)

	return string(result)
}
