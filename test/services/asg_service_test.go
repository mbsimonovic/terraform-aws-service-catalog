package services

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"
	"github.com/gruntwork-io/terratest/modules/git"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestAsgService(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-central-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_asg", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/services/asg-service"

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
		buildASGAmi(t, testFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployASG(t, testFolder)
	})

	test_structure.RunTestStage(t, "validate_asg", func() {
		validateASG(t, testFolder)
	})
}

func buildASGAmi(t *testing.T, testFolder string) {
	awsRegion := aws.GetRandomStableRegion(t, []string{}, []string{})
	test_structure.SaveString(t, testFolder, "region", awsRegion)

	branchName := git.GetCurrentBranchName(t)
	packerOptions := &packer.Options{
		Template: "../examples/for-learning-and-testing/services/asg-service/ami-example.json",
		Vars: map[string]string{
			"aws_region":                    awsRegion,
			"version_tag":                   branchName,
			"service_catalog_ref":           branchName,
			"bash_commons_version":          "v0.1.2",
			"module_aws_monitoring_version": "v0.19.0",
			"module_security_version":       "v0.25.1",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	amiId := packer.BuildArtifact(t, packerOptions)
	test_structure.SaveArtifactID(t, testFolder, amiId)
}

func deployASG(t *testing.T, testFolder string) {
	amiId := test_structure.LoadArtifactID(t, testFolder)
	awsRegion := test_structure.LoadString(t, testFolder, "region")
	name := fmt.Sprintf("asg-%s", random.UniqueId())

	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["ami"] = amiId
	terraformOptions.Vars["name"] = name
	terraformOptions.Vars["aws_region"] = awsRegion

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func validateASG(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

	deployedLbDnsName := terraform.Output(t, terraformOptions, "lb_dns_name")
	lbUrl := fmt.Sprintf("http://%s", deployedLbDnsName)

	forwardRoot := fmt.Sprintf("%s", lbUrl)
	http_helper.HttpGetWithRetry(t, forwardRoot, nil, 200, "Hello, World", 20, 5*time.Second)
}
