package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestJenkins(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_vaildate", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/mgmt/jenkins"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		awsRegion := aws.GetRandomRegion(t, acmRegionsForTest, nil)
		branchName := git.GetCurrentBranchName(t)

		packerOptions := &packer.Options{
			Template: "../modules/mgmt/jenkins/jenkins-ubuntu.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			RetryableErrors: map[string]string{
				"Could not connect to pkg.jenkins.io": "The Jenkins Debian repo sometimes has connectivity issues",
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, testFolder, "region", awsRegion)
		test_structure.SaveArtifactID(t, testFolder, amiId)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")

		name := fmt.Sprintf("jenkins-%s", random.UniqueId())

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region":                 awsRegion,
				"name":                       name,
				"ami_id":                     amiId,
				"base_domain_name":           baseDomainForTest,
				"jenkins_subdomain":          name,
				"acm_ssl_certificate_domain": acmDomainForTest,
				"base_domain_name_tags":      domainNameTagsForTest,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		jenkinsDomainName := terraform.OutputRequired(t, terraformOptions, "jenkins_domain_name")

		url := fmt.Sprintf("https://%s/login", jenkinsDomainName)
		retries := 60
		timeBetweenRetries := 5 * time.Second

		http_helper.HttpGetWithRetryWithCustomValidation(t, url, nil, retries, timeBetweenRetries, func(status int, body string) bool {
			return status == 200 && strings.Contains(body, "Unlock Jenkins")
		})
	})
}