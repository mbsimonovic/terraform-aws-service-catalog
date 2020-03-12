package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestAurora(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")

	testFolder := "../examples/for-learning-and-testing/data-stores/aurora"

	defer test_structure.RunTestStage(t, "cleanup_keypair", func() {
		keypair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, keypair)
	})
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

		keyPair := ssh.GenerateRSAKeyPair(t, 4096)
		awsKeyPair := terraAws.ImportEC2KeyPair(t, awsRegion, uniqueID, keyPair)
		test_structure.SaveEc2KeyPair(t, workingDir, awsKeyPair)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
		dbPassword := test_structure.LoadString(t, testFolder, "password")
		keypair := test_structure.LoadEc2KeyPair(t, workingDir)

		name := fmt.Sprintf("test-aurora-%s", uniqueID)

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region":                     awsRegion,
				"name":                           name,
				"db_name":                        "aurora",
				"master_username":                "aurora",
				"master_password":                dbPassword,
				"share_snapshot_with_account_id": getExternalAccountId(),
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	// TODO: Add validation for aurora server. Requires terratest routine for setting up an SSH port forward.
}
