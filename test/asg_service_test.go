package test

import (
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func TestAsgService(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	os.Setenv("TERRATEST_REGION", "eu-central-1")
	os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_cluster", "true")
	//os.Setenv("SKIP_deploy_core_services", "true")
	//os.Setenv("SKIP_validate_external_dns", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/services/asg-service"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		kubectlOptions := test_structure.LoadKubectlOptions(t, testFolder)
		os.Remove(kubectlOptions.ConfigPath)

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
		Template: "../examples/for-learning-and-testing/services/asg-service/ami-builder-need-new-name.json",
		Vars: map[string]string{
			"aws_region":          awsRegion,
			"version_tag":         branchName,
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	amiId := packer.BuildArtifact(t, packerOptions)
	test_structure.SaveArtifactID(t, testFolder, amiId)

	//awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	//test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
}

func deployASG(t *testing.T, testFolder string) {
	amiId := "ami-0e342d72b12109f91" // test_structure.LoadArtifactID(t, testFolder) // Ubuntu Server 18.04 LTS (HVM), SSD Volume Type
	awsRegion := "eu-central-1" //test_structure.LoadString(t, testFolder, "region")
	//awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

	terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["ami"] = amiId
	terraformOptions.Vars["name"] = "marina"
	terraformOptions.Vars["aws_region"] = awsRegion

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func validateASG(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")

	assert.Equal(t, eksClusterArn, "TODO")
}

