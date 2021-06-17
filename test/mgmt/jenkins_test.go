package mgmt

import (
	"fmt"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestJenkins(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../../examples/for-learning-and-testing/mgmt/jenkins"
	branchName := git.GetCurrentBranchName(t)

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		uniqueId := random.UniqueId()
		test_structure.SaveString(t, testFolder, "uniqueId", uniqueId)

		awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		packerOptions := &packer.Options{
			Template: "../../modules/mgmt/jenkins/jenkins-ubuntu.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
				"encrypt_boot":        "false",
			},
			RetryableErrors: map[string]string{
				"Could not connect to pkg.jenkins.io": "The Jenkins Debian repo sometimes has connectivity issues",
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)
		test_structure.SaveArtifactID(t, testFolder, amiId)

		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueId := test_structure.LoadString(t, testFolder, "uniqueId")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

		name := fmt.Sprintf("jenkins-%s", uniqueId)

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["name"] = name
		terraformOptions.Vars["ami_version_tag"] = branchName
		terraformOptions.Vars["base_domain_name"] = test.BaseDomainForTest
		terraformOptions.Vars["jenkins_subdomain"] = name
		terraformOptions.Vars["acm_ssl_certificate_domain"] = test.AcmDomainForTest
		terraformOptions.Vars["base_domain_name_tags"] = test.DomainNameTagsForTest
		terraformOptions.Vars["keypair_name"] = awsKeyPair.Name
		// As our tests execute super fast, they sometimes failed as the volumes
		// snapshot was triggered as soon as the backup lambda function was created
		// (this is the default behavior of Lambdas) and the teardown process was
		// initiated right after it. Given that the volumes snapshotting usually
		// takes approximately 15~20 minutes, the teardown process timed out.
		// So, in tests, we disable the backup routines due to this.
		terraformOptions.Vars["backup_using_lambda"] = false
		terraformOptions.Vars["backup_using_dlm"] = false

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		jenkinsDomainName := terraform.OutputRequired(t, terraformOptions, "jenkins_domain_name")

		url := fmt.Sprintf("https://%s/login", jenkinsDomainName)
		retries := 60
		timeBetweenRetries := 5 * time.Second

		// Make sure to check that jenkins properly started on the EBS volume by checking if the secrets location is
		// `/jenkins` and not the default `/var/lib/jenkins`
		re, err := regexp.Compile(`<code>\s*/jenkins/secrets/initialAdminPassword\s*</code>`)
		require.NoError(t, err)
		http_helper.HttpGetWithRetryWithCustomValidation(t, url, nil, retries, timeBetweenRetries, func(status int, body string) bool {
			return status == 200 && strings.Contains(body, "Unlock Jenkins") && re.MatchString(body)
		})
	})
}
