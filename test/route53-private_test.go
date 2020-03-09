package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"

	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestRoute53Private(t *testing.T) {
	t.Parallel()

	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")

	uniqueID := random.UniqueId()
	testFolder := "../examples/for-learning-and-testing/networking/route53-private"
	testRegion := "us-west-1"
	testBucket := fmt.Sprintf("route53-private-%s", uniqueID)

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	// Generate and save a test region and a unique zone name
	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, regionsForTest, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		zoneName := fmt.Sprintf("route53-private-%s.xyz", random.UniqueId())
		test_structure.SaveString(t, testFolder, "zonename", zoneName)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {

		zoneName := test_structure.LoadString(t, testFolder, "zonename")

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"internal_services_domain_name": zoneName,
				"aws_region":                    testRegion,
				"aws_account_id":                aws.GetAccountId(t),
				"vpc_name":                      aws.GetDefaultVpc(t, testRegion).Name,
				"vpc_id":                        aws.GetDefaultVpc(t, testRegion).Id,
				"terraform_state_aws_region":    testRegion,
				"terraform_state_s3_bucket":     testBucket,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		internalDomainName := terraform.OutputRequired(t, terraformOptions, "internal_services_domain_name")
		internalZoneID := terraform.OutputRequired(t, terraformOptions, "internal_services_hosted_zone_id")
		internalZoneNameServers := terraform.OutputRequired(t, terraformOptions, "internal_services_name_servers")

		require.NotNil(t, internalDomainName)
		require.NotNil(t, internalZoneID)
		require.NotNil(t, internalZoneNameServers)
	})

}
