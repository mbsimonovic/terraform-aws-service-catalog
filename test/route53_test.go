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

func TestRoute53(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")

	uniqueID := random.UniqueId()
	testFolder := "../examples/for-learning-and-testing/networking/route53"

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	//TODO: Figure out why certain regiosn don't have default VPCs
	// For the time being, hardcode the region to us-west-1
	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, []string{"us-west-1"}, nil)

		test_structure.SaveString(t, testFolder, "region", awsRegion)

		privateZoneName := fmt.Sprintf("gruntwork-test-%s.xyz", uniqueID)
		publicZoneName := fmt.Sprintf("gruntwork-test-%s.com", uniqueID)

		var privateZones = map[string]interface{}{
			privateZoneName: map[string]interface{}{
				"name":          privateZoneName,
				"comment":       "This is an optional test comment",
				"vpc_id":        aws.GetDefaultVpc(t, awsRegion).Id,
				"tags":          domainNameTagsForTest,
				"force_destroy": "true",
			},
		}

		var publicZones = map[string]interface{}{
			publicZoneName: map[string]interface{}{
				"name":          publicZoneName,
				"comment":       "This is another optional test comment",
				"vpc_id":        aws.GetDefaultVpc(t, awsRegion).Id,
				"tags":          domainNameTagsForTest,
				"force_destroy": "true",
			},
		}

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"private_zones": privateZones,
				"public_zones":  publicZones,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		privateDomainNames := terraform.OutputRequired(t, terraformOptions, "private_domain_names")
		privateZonesIds := terraform.OutputRequired(t, terraformOptions, "private_zones_ids")
		privateZonesNameServers := terraform.OutputRequired(t, terraformOptions, "private_zones_name_servers")

		publicDomainNames := terraform.OutputRequired(t, terraformOptions, "public_domain_names")
		publicZonesIds := terraform.OutputRequired(t, terraformOptions, "public_hosted_zones_ids")
		publicZonesNameServers := terraform.OutputRequired(t, terraformOptions, "public_hosted_zones_name_servers")

		require.NotNil(t, privateDomainNames)
		require.NotNil(t, privateZonesIds)
		require.NotNil(t, privateZonesNameServers)

		require.NotNil(t, publicDomainNames)
		require.NotNil(t, publicZonesIds)
		require.NotNil(t, publicZonesNameServers)
	})

}
