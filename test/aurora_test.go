package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
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

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/aurora")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, regionsThatSupportAuroraServerless, nil)
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

		terraformOptions := createAuroraTerraformOptions(t, testFolder, awsRegion, uniqueID, dbPassword)
		terraformOptions.Vars["engine_mode"] = "serverless"
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	// TODO: serverless Aurora can't be publicly exposed, so we need an alternate validation test that hops through a
	// proxy.
}

func TestAurora(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_validate_kubernetes", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/aurora")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)

		kubectlOptions := test_structure.LoadKubectlOptions(t, testFolder)
		k8s.DeleteNamespace(t, kubectlOptions, kubectlOptions.Namespace)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

		dbPassword := fmt.Sprintf("%s-%s", random.UniqueId(), random.UniqueId())
		test_structure.SaveString(t, testFolder, "password", dbPassword)

		// Create a test kubernetes namespace to deploy resources into, to avoid colliding with other tests
		testNamespace := strings.ToLower(uniqueID)
		test_structure.SaveString(t, testFolder, "testNamespace", testNamespace)
		kubectlOptions := k8s.NewKubectlOptions("", "", testNamespace)
		k8s.CreateNamespace(t, kubectlOptions, testNamespace)
		test_structure.SaveKubectlOptions(t, testFolder, kubectlOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		dbPassword := test_structure.LoadString(t, testFolder, "password")
		testNamespace := test_structure.LoadString(t, testFolder, "testNamespace")

		terraformOptions := createAuroraTerraformOptions(t, testFolder, awsRegion, uniqueID, dbPassword)
		terraformOptions.Vars["create_kubernetes_service"] = true
		terraformOptions.Vars["kubernetes_namespace"] = testNamespace
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	// We run the following validation functions in parallel by using subtests. However, subtest parallelization has a
	// quirk where it will not wait for all the tests to finish by default. This could cause this test routine to start
	// running the cleanup functions while the validation functions are running.
	// The way to solve this is to use a subtest that is run in serial to group the parallel subtests.
	t.Run("validation", func(t *testing.T) {
		dbName := "aurora"
		dbUsername := "aurora"
		dbPassword := test_structure.LoadString(t, testFolder, "password")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		clusterName := terraformOptions.Vars["name"]
		dbEndpoint := terraform.OutputRequired(t, terraformOptions, "primary_endpoint")
		dbPort := terraform.OutputRequired(t, terraformOptions, "port")

		t.Run("local", func(t *testing.T) {
			t.Parallel()
			test_structure.RunTestStage(t, "validate", func() {
				info := RDSInfo{
					Username:   dbUsername,
					Password:   dbPassword,
					DBName:     dbName,
					DBEndpoint: dbEndpoint,
					DBPort:     dbPort,
				}
				smokeTestMysql(t, info)
			})
		})

		t.Run("kubernetes", func(t *testing.T) {
			t.Parallel()
			test_structure.RunTestStage(t, "validate_kubernetes", func() {
				kubectlOptions := test_structure.LoadKubectlOptions(t, testFolder)
				info := RDSInfo{
					Username:   dbUsername,
					Password:   dbPassword,
					DBName:     dbName,
					DBEndpoint: fmt.Sprintf("%s.%s.svc.cluster.local", clusterName, kubectlOptions.Namespace),
					DBPort:     dbPort,
				}
				smokeTestMysqlWithKubernetes(t, kubectlOptions, info)
			})
		})
	})
}

func createAuroraTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
	password string,
) *terraform.Options {
	name := fmt.Sprintf("test-aurora-%s", uniqueID)
	terraformOptions := createBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["name"] = name
	terraformOptions.Vars["db_name"] = "aurora"
	terraformOptions.Vars["master_username"] = "aurora"
	terraformOptions.Vars["master_password"] = password
	terraformOptions.Vars["share_snapshot_with_account_id"] = getExternalAccountId()
	return terraformOptions
}
