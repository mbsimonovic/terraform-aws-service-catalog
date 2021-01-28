package networking

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAlb(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_server", "true")
	//os.Setenv("SKIP_validate_access_logs", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := "../../examples/for-learning-and-testing/networking/alb"

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)

		test_structure.SaveString(t, testFolder, "region", awsRegion)

		name := fmt.Sprintf("alb-%s", random.UniqueId())

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["alb_name"] = name
		terraformOptions.Vars["base_domain_name"] = test.BaseDomainForTest
		terraformOptions.Vars["alb_subdomain"] = name
		terraformOptions.Vars["base_domain_name_tags"] = test.DomainNameTagsForTest

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_server", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		albDomainNames := terraform.OutputList(t, terraformOptions, "alb_dns_names")

		// Only test the domains with gruntwork.in, as that domain is the only one configured in the listener.
		for _, domainName := range albDomainNames {
			if strings.HasSuffix(domainName, "gruntwork.in") {
				url := fmt.Sprintf("http://%s:8080", domainName)
				retries := 60
				timeBetweenRetries := 5 * time.Second

				http_helper.HttpGetWithRetryWithCustomValidation(t, url, nil, retries, timeBetweenRetries, func(status int, body string) bool {
					return status == 200 && body == "Hello, World!"
				})
			}
		}
	})

	test_structure.RunTestStage(t, "validate_access_logs", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		accessLogsBucket := terraform.OutputRequired(t, terraformOptions, "alb_access_logs_bucket")
		region := test_structure.LoadString(t, testFolder, "region")

		client := aws.NewS3Client(t, region)

		output, err := client.ListObjects(&s3.ListObjectsInput{Bucket: awsgo.String(accessLogsBucket)})

		require.NoError(t, err)

		assert.Greater(t, len(output.Contents), 0)
	})
}

// Ensures that Terraform variable validation catches any attempts to exceed the ALB's name's 32 character limit
func TestAlbNameLengthValidation(t *testing.T) {
	t.Parallel()

	var validationErrorMsg = "Your alb_name must be 32 characters or less in length."

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/networking/alb")

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)

		test_structure.SaveString(t, testFolder, "region", awsRegion)

		// AWS imposes a 32 character limit on ALB names, so we'll intentionally exceed it here
		// to test that our variable validation catches the issue and returns an error
		overlyLongALBName := fmt.Sprintf("alb-name-that-is-intentionally-too-long-%s", random.UniqueId())

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["alb_name"] = overlyLongALBName
		terraformOptions.Vars["base_domain_name"] = test.BaseDomainForTest
		terraformOptions.Vars["alb_subdomain"] = overlyLongALBName
		terraformOptions.Vars["base_domain_name_tags"] = test.DomainNameTagsForTest

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		_, err := terraform.InitAndApplyE(t, terraformOptions)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), validationErrorMsg)
	})
}
