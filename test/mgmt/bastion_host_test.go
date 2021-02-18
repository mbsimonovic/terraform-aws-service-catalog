package mgmt

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestBastionHost(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../..", "examples/for-learning-and-testing/mgmt/bastion-host")
	branchName := git.GetCurrentBranchName(t)

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		awsRegion := aws.GetRandomStableRegion(t, test.RegionsForEc2Tests, nil)

		packerOptions := &packer.Options{
			Template: "../../modules/mgmt/bastion-host/bastion-host.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, testFolder, "region", awsRegion)
		test_structure.SaveArtifactID(t, testFolder, amiId)
	})

	// Spawn two sub tests in parallel using the same AMI. Note that we wrap the sub tests in a synchronous test group
	// so that the AMI cleanup stage waits for the two subtests to finish.
	t.Run("group", func(t *testing.T) {
		t.Run("WithDomain", func(t *testing.T) {
			t.Parallel()
			testBastionHelper(t, testFolder, branchName, test.BaseDomainForTest)
		})
		t.Run("WithoutDomain", func(t *testing.T) {
			t.Parallel()
			testBastionHelper(t, testFolder, branchName, "")
		})
	})
}

func testBastionHelper(t *testing.T, workingDir string, branchName string, domainName string) {
	defer test_structure.RunTestStage(t, "cleanup_keypair", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, workingDir)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		name := fmt.Sprintf("bastion-host-%s", random.UniqueId())
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		uniqueId := random.UniqueId()
		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)

		terraformOptions := test.CreateBaseTerraformOptions(t, workingDir, awsRegion)
		terraformOptions.Vars["aws_region"] = awsRegion
		terraformOptions.Vars["name"] = name
		terraformOptions.Vars["ami_version_tag"] = branchName
		terraformOptions.Vars["base_domain_name_tags"] = test.DomainNameTagsForTest
		terraformOptions.Vars["keypair_name"] = awsKeyPair.Name

		if domainName == "" {
			terraformOptions.Vars["create_dns_record"] = false
		} else {
			terraformOptions.Vars["create_dns_record"] = true
			terraformOptions.Vars["domain_name"] = domainName
		}

		test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
		test_structure.SaveEc2KeyPair(t, workingDir, awsKeyPair)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, workingDir)
		ip := terraform.OutputRequired(t, terraformOptions, "bastion_host_public_ip")
		test.TestSSH(t, ip, "ubuntu", awsKeyPair)
	})
}
